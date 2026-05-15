import UIKit

final class ProductListViewController: UIViewController {
    var category: String = ""
    var onProductSelected: ((Product, String?) -> Void)?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchController = UISearchController(searchResultsController: nil)

    private var products: [Product] = []
    private var filteredProducts: [Product] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = category.capitalized + " products"
        view.backgroundColor = .systemBackground

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "Search products"
        navigationItem.searchController = searchController

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ProductCell")
        tableView.dataSource = self
        tableView.delegate = self

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadProducts()
    }

    private func loadProducts() {
        ProductAPIService.shared.fetchProducts(category: category) { [weak self] result in
            switch result {
            case .success(let products):
                self?.products = products
                self?.applyFilter()
            case .failure:
                self?.showMessage("Could not load products from API.")
            }
        }
    }

    private func applyFilter() {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if query.isEmpty {
            filteredProducts = products
        } else {
            filteredProducts = products.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query)
            }
        }
        tableView.reloadData()
    }

    private func showVariantSelector(for product: Product) {
        if product.variants.isEmpty {
            onProductSelected?(product, nil)
            navigationController?.popViewController(animated: true)
            return
        }

        let alert = UIAlertController(title: "Select Variant", message: product.name, preferredStyle: .actionSheet)
        for variant in product.variants {
            alert.addAction(UIAlertAction(title: variant, style: .default, handler: { [weak self] _ in
                self?.onProductSelected?(product, variant)
                self?.navigationController?.popViewController(animated: true)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "Home Quote", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension ProductListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredProducts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let product = filteredProducts[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProductCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = product.name
        content.secondaryText = "$\(String(format: "%.2f", product.pricePerSqm))/m²"
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showVariantSelector(for: filteredProducts[indexPath.row])
    }
}

extension ProductListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applyFilter()
    }
}
