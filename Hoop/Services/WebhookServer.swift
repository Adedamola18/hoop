// Hoop/Services/WebhookServer.swift
import Foundation
import Network
import Observation

@Observable
final class WebhookServer {

    private(set) var isRunning = false
    private var listener: NWListener?
    private var continuation: AsyncStream<RawSignal>.Continuation?
    private var _signalStream: AsyncStream<RawSignal>?

    var signalStream: AsyncStream<RawSignal> {
        if let stream = _signalStream { return stream }
        let stream = AsyncStream<RawSignal> { [weak self] continuation in
            self?.continuation = continuation
        }
        _signalStream = stream
        return stream
    }

    var port: UInt16 {
        UInt16(UserDefaults.standard.object(forKey: "webhookPort") as? Int ?? 9876)
    }

    var bearerToken: String? {
        let token = UserDefaults.standard.string(forKey: "webhookBearerToken")
        return token?.isEmpty == true ? nil : token
    }

    func start() {
        guard !isRunning else { return }
        do {
            let params = NWParameters.tcp
            let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: 9876)!
            listener = try NWListener(using: params, on: nwPort)

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isRunning = true
                case .failed, .cancelled:
                    self?.isRunning = false
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                // Enforce localhost-only: reject non-loopback connections
                if case .hostPort(let host, _) = connection.endpoint {
                    let hostStr = "\(host)"
                    if hostStr != "127.0.0.1" && hostStr != "::1" && hostStr != "localhost" {
                        connection.cancel()
                        return
                    }
                }
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            isRunning = false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        continuation?.finish()
    }

    func sendTestAlert() {
        let signal = RawSignal(
            sourceId: "webhook",
            symbol: "TEST/ALERT",
            signalType: .tradingSignal,
            direction: .bullish,
            value: 100.0,
            changePercent: 5.0,
            message: "Test alert from webhook server",
            timestamp: Date()
        )
        continuation?.yield(signal)
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            defer { connection.cancel() }
            guard let self, let data else { return }

            let httpString = String(data: data, encoding: .utf8) ?? ""

            // Verify POST method
            guard httpString.hasPrefix("POST") else {
                self.sendHTTPResponse(connection: connection, status: 405, body: "Method Not Allowed")
                return
            }

            // Check bearer token if configured
            if let expectedToken = self.bearerToken {
                guard httpString.contains("Authorization: Bearer \(expectedToken)") else {
                    self.sendHTTPResponse(connection: connection, status: 401, body: "Unauthorized")
                    return
                }
            }

            // Extract JSON body (after double newline)
            guard let bodyRange = httpString.range(of: "\r\n\r\n") ?? httpString.range(of: "\n\n") else {
                self.sendHTTPResponse(connection: connection, status: 400, body: "No body")
                return
            }

            let bodyString = String(httpString[bodyRange.upperBound...])
            guard let bodyData = bodyString.data(using: .utf8) else {
                self.sendHTTPResponse(connection: connection, status: 400, body: "Invalid body")
                return
            }

            if let signal = self.parseTradingViewPayload(bodyData) {
                self.continuation?.yield(signal)
                self.sendHTTPResponse(connection: connection, status: 200, body: "OK")
            } else {
                self.sendHTTPResponse(connection: connection, status: 400, body: "Parse error")
            }
        }
    }

    private func parseTradingViewPayload(_ data: Data) -> RawSignal? {
        // TradingView webhook format: {"ticker": "BTCUSDT", "action": "buy"/"sell", "price": 70000, "message": "..."}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let symbol = json["ticker"] as? String ?? json["symbol"] as? String ?? "UNKNOWN"
        let action = json["action"] as? String ?? ""
        let price = json["price"] as? Double ?? json["close"] as? Double ?? 0
        let message = json["message"] as? String ?? json["comment"] as? String

        let direction: Direction
        switch action.lowercased() {
        case "buy", "long": direction = .bullish
        case "sell", "short": direction = .bearish
        default: direction = .neutral
        }

        return RawSignal(
            sourceId: "webhook",
            symbol: symbol,
            signalType: .tradingSignal,
            direction: direction,
            value: price,
            changePercent: nil,
            message: message,
            timestamp: Date()
        )
    }

    private func sendHTTPResponse(connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 405: statusText = "Method Not Allowed"
        default: statusText = "Error"
        }
        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in }))
    }
}
