import UIKit

final class HouseDetailViewController: UIViewController {
    var house: House!

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let countLabel = UILabel()
    private let searchBar = UISearchBar()

    private var rooms: [Room] = []
    private var filteredRooms: [Room] = []
    private var expanded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = house.customerName.isEmpty ? "House Rooms" : house.customerName
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Quote", style: .plain, target: self, action: #selector(openQuote)),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addRoomTapped))
        ]

        searchBar.placeholder = "Search rooms"
        searchBar.delegate = self

        countLabel.font = .preferredFont(forTextStyle: .subheadline)
        countLabel.textColor = .secondaryLabel

        [searchBar, countLabel, tableView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RoomCell")
        tableView.dataSource = self
        tableView.delegate = self

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            countLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
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
        loadRooms()
    }

    private func loadRooms() {
        guard let houseId = house.id else { return }
        FirestoreService.shared.fetchRooms(houseId: houseId) { [weak self] rooms in
            self?.rooms = rooms.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self?.applyFilter()
        }
    }

    @objc private func addRoomTapped() {
        let alert = UIAlertController(title: "Add Room", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Room name" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            guard let houseId = self.house.id else { return }
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else {
                self.showMessage("Room name is required.")
                return
            }
            let room = Room(houseId: houseId, name: name)
            FirestoreService.shared.saveRoom(room) { [weak self] in
                self?.loadRooms()
            }
        }))
        present(alert, animated: true)
    }

    @objc private func openQuote() {
        let controller = QuoteViewController()
        controller.house = house
        navigationController?.pushViewController(controller, animated: true)
    }

    private func applyFilter() {
        let query = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if query.isEmpty {
            filteredRooms = rooms
        } else {
            filteredRooms = rooms.filter { $0.name.lowercased().contains(query) }
        }
        tableView.reloadData()
        countLabel.text = "Rooms: \(filteredRooms.count)"
    }

    private func showActions(for room: Room) {
        let alert = UIAlertController(title: room.name, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Open", style: .default, handler: { [weak self] _ in
            let controller = RoomDetailViewController()
            controller.house = self?.house
            controller.room = room
            self?.navigationController?.pushViewController(controller, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { [weak self] _ in
            self?.showEditDialog(room)
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            guard let id = room.id else { return }
            FirestoreService.shared.deleteRoom(id) { [weak self] in
                self?.loadRooms()
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showEditDialog(_ room: Room) {
        let alert = UIAlertController(title: "Edit Room", message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.placeholder = "Room name"
            $0.text = room.name
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else {
                self.showMessage("Room name is required.")
                return
            }
            var updated = room
            updated.name = name
            FirestoreService.shared.saveRoom(updated) { [weak self] in
                self?.loadRooms()
            }
        }))
        present(alert, animated: true)
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "Home Quote", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension HouseDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if expanded { return filteredRooms.count }
        return min(2, filteredRooms.count)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let room = filteredRooms[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "RoomCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = room.name
        content.secondaryText = "Tap for room actions"
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showActions(for: filteredRooms[indexPath.row])
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard filteredRooms.count > 2 else { return nil }
        let button = UIButton(type: .system)
        button.setTitle(expanded ? "Show less rooms" : "Show more rooms", for: .normal)
        button.addTarget(self, action: #selector(toggleExpanded), for: .touchUpInside)
        return button
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        filteredRooms.count > 2 ? 44 : 0
    }

    @objc private func toggleExpanded() {
        expanded.toggle()
        tableView.reloadData()
    }
}

extension HouseDetailViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter()
    }
}
