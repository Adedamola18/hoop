// Hoop/Services/Adapters/BybitAdapter.swift
import Foundation

final class BybitAdapter: MarketAdapter {
    let id = "bybit"
    let name = "Bybit"
    let connectionType: ConnectionType = .websocket

    @MainActor private(set) var connectionState: AdapterConnectionState = .disconnected
    private var webSocketTask: URLSessionWebSocketTask?
    private var continuation: AsyncStream<RawSignal>.Continuation?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private var _signalStream: AsyncStream<RawSignal>?

    var signalStream: AsyncStream<RawSignal> {
        if let stream = _signalStream { return stream }
        let stream = AsyncStream<RawSignal> { [weak self] continuation in
            self?.continuation = continuation
        }
        _signalStream = stream
        return stream
    }

    var apiKey: String?
    var watchedSymbols: [String] = ["BTCUSDT", "ETHUSDT"]

    func connect() async throws {
        await MainActor.run { connectionState = .connecting }
        reconnectAttempts = 0

        guard let url = URL(string: "wss://stream.bybit.com/v5/public/spot") else {
            await MainActor.run { connectionState = .failed(URLError(.badURL)) }
            return
        }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Subscribe to tickers
        let args = watchedSymbols.map { "\"tickers.\($0)\"" }.joined(separator: ",")
        let subMessage = "{\"op\":\"subscribe\",\"args\":[\(args)]}"
        try? await webSocketTask?.send(.string(subMessage))

        await MainActor.run { connectionState = .connected }
        receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        Task { @MainActor in connectionState = .disconnected }
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message, let data = text.data(using: .utf8) {
                    if let signal = self.parseTickerMessage(data) {
                        self.continuation?.yield(signal)
                    }
                }
                self.reconnectAttempts = 0
                self.receiveMessages()
            case .failure:
                self.handleDisconnect()
            }
        }
    }

    private func parseTickerMessage(_ data: Data) -> RawSignal? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let topic = json["topic"] as? String, topic.hasPrefix("tickers"),
              let dataDict = json["data"] as? [String: Any],
              let symbol = dataDict["symbol"] as? String,
              let priceStr = dataDict["lastPrice"] as? String, let price = Double(priceStr),
              let changeStr = dataDict["price24hPcnt"] as? String, let changePct = Double(changeStr)
        else { return nil }

        let direction: Direction = changePct >= 0 ? .bullish : .bearish

        return RawSignal(
            sourceId: id,
            symbol: symbol,
            signalType: .priceAlert,
            direction: direction,
            value: price,
            changePercent: changePct * 100,
            message: nil,
            timestamp: Date()
        )
    }

    private func handleDisconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            Task { @MainActor in connectionState = .failed(URLError(.networkConnectionLost)) }
            return
        }
        reconnectAttempts += 1
        let attempt = reconnectAttempts
        Task { @MainActor in connectionState = .reconnecting(attempt: attempt) }
        let delay = min(pow(2.0, Double(reconnectAttempts)), 60.0)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            Task { try? await self?.connect() }
        }
    }
}
