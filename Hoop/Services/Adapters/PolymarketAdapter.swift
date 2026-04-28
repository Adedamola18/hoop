// Hoop/Services/Adapters/PolymarketAdapter.swift
import Foundation

final class PolymarketAdapter: MarketAdapter {
    let id = "polymarket"
    let name = "Polymarket"
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

    var watchedMarketSlugs: [String] = []
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
        Task { await fetchMarkets() } // Immediate first fetch
    }

    private func fetchMarkets() async {
        guard !watchedMarketSlugs.isEmpty else { return }

        // Polymarket CLOB API - batch fetch
        guard let url = URL(string: "https://clob.polymarket.com/markets") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Handle rate limiting
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                await MainActor.run { connectionState = .reconnecting(attempt: reconnectAttempts) }
                reconnectAttempts += 1
                if reconnectAttempts < maxReconnectAttempts {
                    let backoff = min(pow(2.0, Double(reconnectAttempts)), 60.0)
                    try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                } else {
                    await MainActor.run { connectionState = .failed(URLError(.resourceUnavailable)) }
                }
                return
            }

            reconnectAttempts = 0
            await MainActor.run { connectionState = .connected }

            guard let markets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

            for market in markets {
                guard let slug = market["condition_id"] as? String ?? market["question_id"] as? String,
                      watchedMarketSlugs.contains(slug),
                      let question = market["question"] as? String,
                      let priceStr = market["price"] as? String ?? (market["tokens"] as? [[String: Any]])?.first?["price"] as? String,
                      let price = Double(priceStr)
                else { continue }

                let previousPrice = previousPrices[slug] ?? price
                let changePct = previousPrice > 0 ? ((price - previousPrice) / previousPrice) * 100 : 0
                previousPrices[slug] = price

                guard abs(changePct) > 0.1 else { continue } // Skip negligible changes

                let direction: Direction = changePct >= 0 ? .bullish : .bearish

                let signal = RawSignal(
                    sourceId: id,
                    symbol: question,
                    signalType: .predictionShift,
                    direction: direction,
                    value: price * 100, // Convert to percentage
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
