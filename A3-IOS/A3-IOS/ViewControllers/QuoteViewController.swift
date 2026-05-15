import UIKit

final class QuoteViewController: UIViewController {
    var house: House?
    var focusRoom: Room?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let subtotalLabel = UILabel()
    private let totalLabel = UILabel()
    private let discountField = UITextField()
    private let applyDiscountButton = UIButton(type: .system)
    private let clearDiscountButton = UIButton(type: .system)

    private var rooms: [Room] = []
    private var windowsByRoom: [String: [WindowMeasurement]] = [:]
    private var floorsByRoom: [String: [FloorSpace]] = [:]
    private var productsById: [String: Product] = [:]
    private var summary = QuoteSummary(lineItems: [], subtotal: 0, discountPercent: 0, discountAmount: 0, total: 0)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Quote"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareQuote))

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "QuoteCell")
        tableView.dataSource = self
        tableView.delegate = self

        subtotalLabel.font = .preferredFont(forTextStyle: .headline)
        totalLabel.font = .preferredFont(forTextStyle: .title3)

        discountField.borderStyle = .roundedRect
        discountField.keyboardType = .decimalPad
        discountField.placeholder = "Discount %"

        applyDiscountButton.setTitle("Apply", for: .normal)
        applyDiscountButton.addTarget(self, action: #selector(applyDiscount), for: .touchUpInside)

        clearDiscountButton.setTitle("Clear", for: .normal)
        clearDiscountButton.addTarget(self, action: #selector(clearDiscount), for: .touchUpInside)

        let discountRow = UIStackView(arrangedSubviews: [discountField, applyDiscountButton, clearDiscountButton])
        discountRow.axis = .horizontal
        discountRow.spacing = 8
        discountRow.distribution = .fillProportionally
        discountRow.translatesAutoresizingMaskIntoConstraints = false

        let footerStack = UIStackView(arrangedSubviews: [subtotalLabel, discountRow, totalLabel])
        footerStack.axis = .vertical
        footerStack.spacing = 8
        footerStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        view.addSubview(footerStack)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            footerStack.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 8),
            footerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            footerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            footerStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])

        loadAllData()
    }

    private func loadAllData() {
        guard let house else {
            showMessage("No house selected.")
            return
        }

        ProductAPIService.shared.fetchProducts(category: nil) { [weak self] result in
            if case .success(let products) = result {
                self?.productsById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            }
            self?.loadRoomsAndMeasurements(for: house)
        }
    }

    private func loadRoomsAndMeasurements(for house: House) {
        guard let houseId = house.id else { return }
        FirestoreService.shared.fetchRooms(houseId: houseId) { [weak self] rooms in
            guard let self else { return }
            self.rooms = rooms

            let group = DispatchGroup()
            self.windowsByRoom = [:]
            self.floorsByRoom = [:]

            for room in rooms {
                guard let roomId = room.id else { continue }
                group.enter()
                FirestoreService.shared.fetchWindows(roomId: roomId) { windows in
                    self.windowsByRoom[roomId] = windows
                    group.leave()
                }

                group.enter()
                FirestoreService.shared.fetchFloorSpaces(roomId: roomId) { floors in
                    self.floorsByRoom[roomId] = floors
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.refreshQuote()
            }
        }
    }

    private func refreshQuote() {
        guard let house else { return }
        let discount = Double(discountField.text ?? "") ?? 0
        summary = QuoteService.buildQuote(
            house: house,
            rooms: rooms,
            windowsByRoomId: windowsByRoom,
            floorSpacesByRoomId: floorsByRoom,
            productsById: productsById,
            discountPercent: discount
        )

        subtotalLabel.text = "Subtotal: $\(String(format: "%.2f", summary.subtotal))"
        totalLabel.text = "Total: $\(String(format: "%.2f", summary.total))"
        tableView.reloadData()
    }

    @objc private func applyDiscount() {
        refreshQuote()
    }

    @objc private func clearDiscount() {
        discountField.text = ""
        refreshQuote()
    }

    @objc private func shareQuote() {
        guard let house else { return }
        let text = QuoteService.shareText(for: house, summary: summary)
        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(controller, animated: true)
    }

    private func toggleInclude(for lineItem: QuoteLineItem, included: Bool) {
        // A quote line maps to either a window item or a floor-space item, never both.
        if updateWindowInclusion(lineItemId: lineItem.id, included: included) {
            refreshQuote()
            return
        }

        if updateFloorInclusion(lineItemId: lineItem.id, included: included) {
            refreshQuote()
            return
        }

        showMessage("Could not update quote item. Please refresh and try again.")
    }

    private func updateWindowInclusion(lineItemId: String, included: Bool) -> Bool {
        for room in rooms {
            guard let roomId = room.id else { continue }
            guard var windows = windowsByRoom[roomId],
                  let index = windows.firstIndex(where: { ($0.id ?? "") == lineItemId }) else { continue }

            windows[index].includeInQuote = included
            let updated = windows[index]
            windowsByRoom[roomId] = windows
            FirestoreService.shared.saveWindow(updated)
            return true
        }
        return false
    }

    private func updateFloorInclusion(lineItemId: String, included: Bool) -> Bool {
        for room in rooms {
            guard let roomId = room.id else { continue }
            guard var floors = floorsByRoom[roomId],
                  let index = floors.firstIndex(where: { ($0.id ?? "") == lineItemId }) else { continue }

            floors[index].includeInQuote = included
            let updated = floors[index]
            floorsByRoom[roomId] = floors
            FirestoreService.shared.saveFloorSpace(updated)
            return true
        }
        return false
    }

    private func showMessage(_ message: String) {
        let alert = UIAlertController(title: "Home Quote", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension QuoteViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        summary.lineItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = summary.lineItems[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "QuoteCell", for: indexPath)

        var content = cell.defaultContentConfiguration()
        content.text = item.title
        content.secondaryText = "\(item.details) • $\(String(format: "%.2f", item.lineTotal))"
        cell.contentConfiguration = content

        let toggle = UISwitch()
        toggle.isOn = item.included
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(includeSwitchChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle

        return cell
    }

    @objc private func includeSwitchChanged(_ sender: UISwitch) {
        let row = sender.tag
        guard row >= 0, row < summary.lineItems.count else { return }
        toggleInclude(for: summary.lineItems[row], included: sender.isOn)
    }
}
