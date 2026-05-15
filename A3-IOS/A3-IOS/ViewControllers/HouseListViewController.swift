import UIKit

final class HouseListViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let countLabel = UILabel()
    private let searchController = UISearchController(searchResultsController: nil)

    private var houses: [House] = []
    private var filteredHouses: [House] = []
    private var expanded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home Quote"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addHouseTapped))

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "Search houses"
        navigationItem.searchController = searchController
        definesPresentationContext = true

        countLabel.font = .preferredFont(forTextStyle: .subheadline)
        countLabel.textColor = .secondaryLabel

        tableView.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HouseCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()

        view.addSubview(countLabel)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            countLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHouses()
    }

    private func loadHouses() {
        FirestoreService.shared.fetchHouses { [weak self] houses in
            guard let self else { return }
            self.houses = houses.sorted { $0.customerName.localizedCaseInsensitiveCompare($1.customerName) == .orderedAscending }
            self.applyFilter()
        }
    }

    @objc private func addHouseTapped() {
        showHouseDialog(title: "Add House", existing: nil)
    }

    private func showHouseDialog(title: String, existing: House?) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Customer name"
            textField.text = existing?.customerName
        }
        alert.addTextField { textField in
            textField.placeholder = "Address"
            textField.text = existing?.address
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let address = alert.textFields?.last?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard self.validateHouseInput(name: name, address: address) else {
                self.showMessage("Please enter customer name and a valid address with at least one letter.")
                return
            }

            var house = existing ?? House()
            house.customerName = name
            house.address = address

            FirestoreService.shared.saveHouse(house) { [weak self] in
                self?.loadHouses()
            }
        }))

        present(alert, animated: true)
    }

    private func validateHouseInput(name: String, address: String) -> Bool {
        guard !name.isEmpty, !address.isEmpty else { return false }
        return address.contains(where: { $0.isLetter })
    }

    private func applyFilter() {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if query.isEmpty {
            filteredHouses = houses
        } else {
            filteredHouses = houses.filter {
                $0.customerName.lowercased().contains(query) || $0.address.lowercased().contains(query)
            }
        }
        tableView.reloadData()
        countLabel.text = "Houses: \(filteredHouses.count)"
    }

    private func showActions(for house: House) {
        let alert = UIAlertController(title: house.customerName, message: house.address, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Open Rooms", style: .default, handler: { [weak self] _ in
            let controller = HouseDetailViewController()
            controller.house = house
            self?.navigationController?.pushViewController(controller, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "Quote", style: .default, handler: { [weak self] _ in
            let controller = QuoteViewController()
            controller.house = house
            self?.navigationController?.pushViewController(controller, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { [weak self] _ in
            self?.showHouseDialog(title: "Edit House", existing: house)
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            guard let id = house.id else { return }
            FirestoreService.shared.deleteHouse(id) { [weak self] in
                self?.loadHouses()
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "Home Quote", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension HouseListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if expanded { return filteredHouses.count }
        return min(2, filteredHouses.count)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let house = filteredHouses[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "HouseCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = house.customerName.isEmpty ? "Unnamed customer" : house.customerName
        content.secondaryText = house.address.isEmpty ? "No address" : house.address
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showActions(for: filteredHouses[indexPath.row])
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard filteredHouses.count > 2 else { return nil }
        let button = UIButton(type: .system)
        button.setTitle(expanded ? "Show less houses" : "Show more houses", for: .normal)
        button.addTarget(self, action: #selector(toggleExpanded), for: .touchUpInside)
        return button
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        filteredHouses.count > 2 ? 44 : 0
    }

    @objc private func toggleExpanded() {
        expanded.toggle()
        tableView.reloadData()
    }
}

extension HouseListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applyFilter()
    }
}
