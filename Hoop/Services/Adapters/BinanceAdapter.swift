// Hoop/Services/Adapters/BinanceAdapter.swift
import Foundation

final class BinanceAdapter: MarketAdapter {
    let id = "binance"
    let name = "Binance"
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
    var watchedSymbols: [String] = ["btcusdt", "ethusdt"]

    func connect() async throws {
        await MainActor.run { connectionState = .connecting }
        reconnectAttempts = 0

        let streams = watchedSymbols.map { "\($0)@ticker" }.joined(separator: "/")
        guard let url = URL(string: "wss://stream.binance.com:9443/ws/\(streams)") else {
            await MainActor.run { connectionState = .failed(URLError(.badURL)) }
            return
        }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
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
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let symbol = json["s"] as? String,
              let priceStr = json["c"] as? String, let price = Double(priceStr),
              let changeStr = json["P"] as? String, let changePercent = Double(changeStr) else { return nil }

        let direction: Direction = changePercent >= 0 ? .bullish : .bearish

        return RawSignal(
            sourceId: id,
            symbol: symbol,
            signalType: .priceAlert,
            direction: direction,
            value: price,
            changePercent: changePercent,
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
