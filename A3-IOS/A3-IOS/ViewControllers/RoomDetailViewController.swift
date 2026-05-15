import PhotosUI
import UIKit

final class RoomDetailViewController: UIViewController {
    enum Segment: Int {
        case windows
        case floors
    }

    private enum PhotoTarget {
        case room
        case window(WindowMeasurement)
        case floor(FloorSpace)
    }

    var house: House?
    var room: Room!

    private let roomNameField = UITextField()
    private let roomImageView = UIImageView()
    private let roomPhotoButton = UIButton(type: .system)
    private let segmentedControl = UISegmentedControl(items: ["Windows", "Floor Spaces"])
    private let tableView = UITableView(frame: .zero, style: .plain)

    private var windows: [WindowMeasurement] = []
    private var floorSpaces: [FloorSpace] = []
    private var selectedSegment: Segment = .windows

    private var productCache: [String: Product] = [:]
    private var photoTarget: PhotoTarget?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = room.name.isEmpty ? "Room Details" : room.name
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Quote", style: .plain, target: self, action: #selector(openQuote)),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addMeasurementTapped))
        ]

        setupLayout()
        loadData()
        preloadProducts()
    }

    private func setupLayout() {
        roomNameField.borderStyle = .roundedRect
        roomNameField.placeholder = "Room name"
        roomNameField.text = room.name
        roomNameField.addTarget(self, action: #selector(roomNameChanged), for: .editingDidEnd)

        roomImageView.contentMode = .scaleAspectFill
        roomImageView.clipsToBounds = true
        roomImageView.backgroundColor = .secondarySystemBackground
        roomImageView.layer.cornerRadius = 8
        roomImageView.heightAnchor.constraint(equalToConstant: 140).isActive = true

        roomPhotoButton.setTitle("Choose room photo", for: .normal)
        roomPhotoButton.addTarget(self, action: #selector(chooseRoomPhoto), for: .touchUpInside)

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MeasurementCell")
        tableView.dataSource = self
        tableView.delegate = self

        let stack = UIStackView(arrangedSubviews: [roomNameField, roomImageView, roomPhotoButton, segmentedControl, tableView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
    }

    private func loadData() {
        if let image = ImageService.fromBase64(room.photoBase64) {
            roomImageView.image = image
        }

        guard let roomId = room.id else { return }
        FirestoreService.shared.fetchWindows(roomId: roomId) { [weak self] windows in
            self?.windows = windows
            self?.tableView.reloadData()
        }
        FirestoreService.shared.fetchFloorSpaces(roomId: roomId) { [weak self] floors in
            self?.floorSpaces = floors
            self?.tableView.reloadData()
        }
    }

    private func preloadProducts() {
        ProductAPIService.shared.fetchProducts(category: nil) { [weak self] result in
            if case .success(let products) = result {
                self?.productCache = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            }
        }
    }

    @objc private func roomNameChanged() {
        room.name = roomNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        title = room.name.isEmpty ? "Room Details" : room.name
        FirestoreService.shared.saveRoom(room)
    }

    @objc private func chooseRoomPhoto() {
        photoTarget = .room
        presentPhotoPicker()
    }

    @objc private func segmentChanged() {
        selectedSegment = Segment(rawValue: segmentedControl.selectedSegmentIndex) ?? .windows
        tableView.reloadData()
    }

    @objc private func addMeasurementTapped() {
        switch selectedSegment {
        case .windows:
            presentWindowEditor(existing: nil)
        case .floors:
            presentFloorEditor(existing: nil)
        }
    }

    @objc private func openQuote() {
        let controller = QuoteViewController()
        controller.house = house
        controller.focusRoom = room
        navigationController?.pushViewController(controller, animated: true)
    }

    private func presentWindowEditor(existing: WindowMeasurement?) {
        let alert = UIAlertController(title: existing == nil ? "Add Window" : "Edit Window", message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.placeholder = "Name"
            $0.text = existing?.name
        }
        alert.addTextField {
            $0.placeholder = "Width (mm)"
            $0.keyboardType = .decimalPad
            $0.text = existing.map { String(Int($0.widthMm)) }
        }
        alert.addTextField {
            $0.placeholder = "Height (mm)"
            $0.keyboardType = .decimalPad
            $0.text = existing.map { String(Int($0.heightMm)) }
        }
        alert.addTextField {
            $0.placeholder = "Panel count"
            $0.keyboardType = .numberPad
            $0.text = existing.map { String($0.panelCount) }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            guard let roomId = self.room.id else { return }

            let name = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let width = Double(alert.textFields?[1].text ?? "") ?? 0
            let height = Double(alert.textFields?[2].text ?? "") ?? 0
            let panels = Int(alert.textFields?[3].text ?? "") ?? 1

            guard !name.isEmpty, width > 0, height > 0, panels > 0 else {
                self.showMessage("Please provide a name, dimensions, and panel count.")
                return
            }

            var item = existing ?? WindowMeasurement(roomId: roomId)
            item.name = name
            item.widthMm = width
            item.heightMm = height
            item.panelCount = panels

            FirestoreService.shared.saveWindow(item) { [weak self] in
                self?.loadData()
            }
        }))

        if existing != nil {
            alert.addAction(UIAlertAction(title: "Choose Product", style: .default, handler: { [weak self] _ in
                self?.openProductPicker(for: .windows, existingWindow: existing)
            }))
            alert.addAction(UIAlertAction(title: "Choose Photo", style: .default, handler: { [weak self] _ in
                guard let existing else { return }
                self?.photoTarget = .window(existing)
                self?.presentPhotoPicker()
            }))
        }

        present(alert, animated: true)
    }

    private func presentFloorEditor(existing: FloorSpace?) {
        let alert = UIAlertController(title: existing == nil ? "Add Floor Space" : "Edit Floor Space", message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.placeholder = "Name"
            $0.text = existing?.name
        }
        alert.addTextField {
            $0.placeholder = "Width (mm)"
            $0.keyboardType = .decimalPad
            $0.text = existing.map { String(Int($0.widthMm)) }
        }
        alert.addTextField {
            $0.placeholder = "Depth (mm)"
            $0.keyboardType = .decimalPad
            $0.text = existing.map { String(Int($0.depthMm)) }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            guard let roomId = self.room.id else { return }

            let name = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let width = Double(alert.textFields?[1].text ?? "") ?? 0
            let depth = Double(alert.textFields?[2].text ?? "") ?? 0

            guard !name.isEmpty, width > 0, depth > 0 else {
                self.showMessage("Please provide a name and dimensions.")
                return
            }

            var item = existing ?? FloorSpace(roomId: roomId)
            item.name = name
            item.widthMm = width
            item.depthMm = depth

            FirestoreService.shared.saveFloorSpace(item) { [weak self] in
                self?.loadData()
            }
        }))

        if existing != nil {
            alert.addAction(UIAlertAction(title: "Choose Product", style: .default, handler: { [weak self] _ in
                self?.openProductPicker(for: .floors, existingFloor: existing)
            }))
            alert.addAction(UIAlertAction(title: "Choose Photo", style: .default, handler: { [weak self] _ in
                guard let existing else { return }
                self?.photoTarget = .floor(existing)
                self?.presentPhotoPicker()
            }))
        }

        present(alert, animated: true)
    }

    private func openProductPicker(for segment: Segment, existingWindow: WindowMeasurement? = nil, existingFloor: FloorSpace? = nil) {
        let controller = ProductListViewController()
        controller.category = segment == .windows ? "window" : "floor"
        controller.onProductSelected = { [weak self] product, variant in
            guard let self else { return }
            if segment == .windows {
                guard var window = existingWindow else { return }
                let isCompatible = ProductAPIService.shared.isWindowProductCompatible(
                    product: product,
                    widthMm: window.widthMm,
                    heightMm: window.heightMm,
                    panelCount: window.panelCount
                )
                if !isCompatible {
                    self.showMessage("Product is not compatible with this window dimensions/panel count.")
                    return
                }
                window.selectedProductId = product.id
                window.selectedProductName = product.name
                window.selectedProductVariant = variant
                self.productCache[product.id] = product
                FirestoreService.shared.saveWindow(window) { [weak self] in
                    self?.loadData()
                }
            } else {
                guard var floor = existingFloor else { return }
                floor.selectedProductId = product.id
                floor.selectedProductName = product.name
                floor.selectedProductVariant = variant
                self.productCache[product.id] = product
                FirestoreService.shared.saveFloorSpace(floor) { [weak self] in
                    self?.loadData()
                }
            }
        }
        navigationController?.pushViewController(controller, animated: true)
    }

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func showActionsForWindow(_ item: WindowMeasurement) {
        let alert = UIAlertController(title: item.name, message: "Window", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { [weak self] _ in
            self?.presentWindowEditor(existing: item)
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            guard let id = item.id else { return }
            FirestoreService.shared.deleteWindow(id) { [weak self] in
                self?.loadData()
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showActionsForFloor(_ item: FloorSpace) {
        let alert = UIAlertController(title: item.name, message: "Floor space", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { [weak self] _ in
            self?.presentFloorEditor(existing: item)
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            guard let id = item.id else { return }
            FirestoreService.shared.deleteFloorSpace(id) { [weak self] in
                self?.loadData()
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

extension RoomDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch selectedSegment {
        case .windows:
            return windows.count
        case .floors:
            return floorSpaces.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MeasurementCell", for: indexPath)
        var content = cell.defaultContentConfiguration()

        switch selectedSegment {
        case .windows:
            let item = windows[indexPath.row]
            let productName = item.selectedProductName ?? "No product"
            content.text = item.name
            content.secondaryText = "\(Int(item.widthMm))×\(Int(item.heightMm)) mm • \(productName)"
            cell.imageView?.image = ImageService.fromBase64(item.photoBase64)
        case .floors:
            let item = floorSpaces[indexPath.row]
            let productName = item.selectedProductName ?? "No product"
            content.text = item.name
            content.secondaryText = "\(Int(item.widthMm))×\(Int(item.depthMm)) mm • \(productName)"
            cell.imageView?.image = ImageService.fromBase64(item.photoBase64)
        }

        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch selectedSegment {
        case .windows:
            showActionsForWindow(windows[indexPath.row])
        case .floors:
            showActionsForFloor(floorSpaces[indexPath.row])
        }
    }
}

extension RoomDetailViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }

        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                guard let self, let image = image as? UIImage else { return }
                DispatchQueue.main.async {
                    let encoded = ImageService.toBase64(image)
                    switch self.photoTarget {
                    case .room:
                        self.room.photoBase64 = encoded
                        self.roomImageView.image = image
                        FirestoreService.shared.saveRoom(self.room)
                    case .window(var item):
                        item.photoBase64 = encoded
                        FirestoreService.shared.saveWindow(item) { [weak self] in
                            self?.loadData()
                        }
                    case .floor(var item):
                        item.photoBase64 = encoded
                        FirestoreService.shared.saveFloorSpace(item) { [weak self] in
                            self?.loadData()
                        }
                    case .none:
                        break
                    }
                    self.photoTarget = nil
                }
            }
        }
    }
}
