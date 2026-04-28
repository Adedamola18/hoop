// Hoop/Services/Adapters/KalshiAdapter.swift
import Foundation

final class KalshiAdapter: MarketAdapter {
    let id = "kalshi"
    let name = "Kalshi"
    let connectionType: ConnectionType = .polling

    @MainActor private(set) var connectionState: AdapterConnectionState = .disconnected
    private var continuation: AsyncStream<RawSignal>.Continuation?
    private var pollTimer: Timer?
    private var previousPrices: [String: Double] = [:]
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

    var watchedTickers: [String] = []
    var pollIntervalSeconds: TimeInterval = 30

    func connect() async throws {
        await MainActor.run { connectionState = .connecting }
        reconnectAttempts = 0
        await MainActor.run { connectionState = .connected }
        startPolling()
    }

    func disconnect() {
        pollTimer?.invalidate()
        pollTimer = nil
        Task { @MainActor in connectionState = .disconnected }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollIntervalSeconds, repeats: true) { [weak self] _ in
            Task { await self?.fetchMarkets() }
        }
        Task { await fetchMarkets() }
    }

    private func fetchMarkets() async {
        guard !watchedTickers.isEmpty else { return }

        // Kalshi API v2 - markets endpoint
        let tickerParam = watchedTickers.joined(separator: ",")
        guard let url = URL(string: "https://api.elections.kalshi.com/trade-api/v2/markets?tickers=\(tickerParam)") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                reconnectAttempts += 1
                let attempt = reconnectAttempts
                await MainActor.run { connectionState = .reconnecting(attempt: attempt) }
                if reconnectAttempts >= maxReconnectAttempts {
                    await MainActor.run { connectionState = .failed(URLError(.resourceUnavailable)) }
                }
                return
            }

            reconnectAttempts = 0
            await MainActor.run { connectionState = .connected }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let markets = json["markets"] as? [[String: Any]] else { return }

            for market in markets {
                guard let ticker = market["ticker"] as? String,
                      let title = market["title"] as? String,
                      let yesPrice = market["yes_bid"] as? Double ?? market["last_price"] as? Double
                else { continue }

                let previousPrice = previousPrices[ticker] ?? yesPrice
                let changePct = previousPrice > 0 ? ((yesPrice - previousPrice) / previousPrice) * 100 : 0
                previousPrices[ticker] = yesPrice

                guard abs(changePct) > 0.1 else { continue }

                let direction: Direction = changePct >= 0 ? .bullish : .bearish

                let signal = RawSignal(
                    sourceId: id,
                    symbol: title,
                    signalType: .predictionShift,
                    direction: direction,
                    value: yesPrice * 100,
                    changePercent: changePct,
                    message: nil,
                    timestamp: Date()
                )
                continuation?.yield(signal)
            }
        } catch {
            if reconnectAttempts < maxReconnectAttempts {
                reconnectAttempts += 1
                let attempt = reconnectAttempts
                await MainActor.run { connectionState = .reconnecting(attempt: attempt) }
            } else {
                let err = error
                await MainActor.run { connectionState = .failed(err) }
            }
        }
    }
}
