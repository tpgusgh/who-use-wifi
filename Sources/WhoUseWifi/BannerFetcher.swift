import Foundation

enum BannerFetcher {
    static func fetch(host: String, port: UInt16) async -> (banner: String?, title: String?) {
        for scheme in ["http", "https"] {
            if let result = await tryFetch(scheme: scheme, host: host, port: port) {
                return result
            }
        }
        return (nil, nil)
    }

    private static func tryFetch(scheme: String, host: String, port: UInt16) async -> (String?, String?)? {
        guard let url = URL(string: "\(scheme)://\(host):\(port)/") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.5
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)
            let banner = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Server")
            let title = extractTitle(from: data)
            if banner == nil && title == nil { return nil }
            return (banner, title)
        } catch {
            return nil
        }
    }

    private static func extractTitle(from data: Data) -> String? {
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        guard let start = html.range(of: "<title>", options: .caseInsensitive) else { return nil }
        guard let end = html.range(of: "</title>", options: .caseInsensitive, range: start.upperBound..<html.endIndex) else { return nil }
        let title = html[start.upperBound..<end.lowerBound]
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
