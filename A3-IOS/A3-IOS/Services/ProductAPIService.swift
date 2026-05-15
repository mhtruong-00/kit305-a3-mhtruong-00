import Foundation

final class ProductAPIService {
    static let shared = ProductAPIService()

    private let decoder = JSONDecoder()

    private init() {}

    func fetchProducts(category: String?, completion: @escaping (Result<[Product], Error>) -> Void) {
        var endpoint = "https://utasbot.dev/kit305_2026/product"
        if let category, !category.isEmpty {
            endpoint += "?category=\(category)"
        }

        guard let url = URL(string: endpoint) else {
            completion(.success([]))
            return
        }

        URLSession.shared.dataTask(with: url) { [decoder] data, _, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data else {
                DispatchQueue.main.async { completion(.success([])) }
                return
            }

            do {
                let products = try decoder.decode([Product].self, from: data)
                DispatchQueue.main.async { completion(.success(products)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    func isWindowProductCompatible(product: Product, widthMm: Double, heightMm: Double, panelCount: Int) -> Bool {
        if let minWidth = product.minWidth, widthMm < minWidth { return false }
        if let maxWidth = product.maxWidth, widthMm > maxWidth { return false }
        if let minHeight = product.minHeight, heightMm < minHeight { return false }
        if let maxHeight = product.maxHeight, heightMm > maxHeight { return false }
        if let maxPanelCount = product.maxPanelCount, panelCount > maxPanelCount { return false }
        return true
    }
}
