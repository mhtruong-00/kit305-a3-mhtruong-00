import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class FirestoreService {
    static let shared = FirestoreService()

    private let housesKey = "homequote.houses"
    private let roomsKey = "homequote.rooms"
    private let windowsKey = "homequote.windows"
    private let floorsKey = "homequote.floors"

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

#if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
#endif

    private init() {}

    func fetchHouses(completion: @escaping ([House]) -> Void) {
#if canImport(FirebaseFirestore)
        db.collection("houses").getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else {
                completion([])
                return
            }
            let houses = docs.compactMap { doc -> House? in
                let data = doc.data()
                return House(
                    id: doc.documentID,
                    customerName: data["customerName"] as? String ?? "",
                    address: data["address"] as? String ?? ""
                )
            }
            completion(houses)
        }
#else
        completion(read(key: housesKey, as: [House].self) ?? [])
#endif
    }

    func saveHouse(_ house: House, completion: (() -> Void)? = nil) {
#if canImport(FirebaseFirestore)
        if let id = house.id, !id.isEmpty {
            db.collection("houses").document(id).setData([
                "customerName": house.customerName,
                "address": house.address
            ])
            completion?()
            return
        }
        var toSave = house
        let reference = db.collection("houses").document()
        toSave.id = reference.documentID
        reference.setData([
            "customerName": toSave.customerName,
            "address": toSave.address
        ])
        completion?()
#else
        var houses = read(key: housesKey, as: [House].self) ?? []
        var editable = house
        if editable.id?.isEmpty ?? true {
            editable.id = UUID().uuidString
        }

        if let index = houses.firstIndex(where: { $0.id == editable.id }) {
            houses[index] = editable
        } else {
            houses.insert(editable, at: 0)
        }
        write(value: houses, key: housesKey)
        completion?()
#endif
    }

    func deleteHouse(_ houseId: String, completion: (() -> Void)? = nil) {
#if canImport(FirebaseFirestore)
        db.collection("houses").document(houseId).delete { _ in completion?() }
#else
        var houses = read(key: housesKey, as: [House].self) ?? []
        houses.removeAll { $0.id == houseId }
        write(value: houses, key: housesKey)

        var rooms = read(key: roomsKey, as: [Room].self) ?? []
        let roomIds = Set(rooms.filter { $0.houseId == houseId }.compactMap(\.id))
        rooms.removeAll { $0.houseId == houseId }
        write(value: rooms, key: roomsKey)

        var windows = read(key: windowsKey, as: [WindowMeasurement].self) ?? []
        windows.removeAll { roomIds.contains($0.roomId) }
        write(value: windows, key: windowsKey)

        var floors = read(key: floorsKey, as: [FloorSpace].self) ?? []
        floors.removeAll { roomIds.contains($0.roomId) }
        write(value: floors, key: floorsKey)
        completion?()
#endif
    }

    func fetchRooms(houseId: String, completion: @escaping ([Room]) -> Void) {
#if canImport(FirebaseFirestore)
        db.collection("rooms").whereField("houseId", isEqualTo: houseId).getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else {
                completion([])
                return
            }
            let rooms = docs.compactMap { doc -> Room? in
                let data = doc.data()
                return Room(
                    id: doc.documentID,
                    houseId: data["houseId"] as? String ?? "",
                    name: data["name"] as? String ?? "",
                    photoBase64: data["photoBase64"] as? String
                )
            }
            completion(rooms)
        }
#else
        let rooms = (read(key: roomsKey, as: [Room].self) ?? []).filter { $0.houseId == houseId }
        completion(rooms)
#endif
    }

    func saveRoom(_ room: Room, completion: (() -> Void)? = nil) {
#if canImport(FirebaseFirestore)
        if let id = room.id, !id.isEmpty {
            db.collection("rooms").document(id).setData([
                "houseId": room.houseId,
                "name": room.name,
                "photoBase64": room.photoBase64 as Any
            ])
            completion?()
            return
        }
        var toSave = room
        let reference = db.collection("rooms").document()
        toSave.id = reference.documentID
        reference.setData([
            "houseId": toSave.houseId,
            "name": toSave.name,
            "photoBase64": toSave.photoBase64 as Any
        ])
        completion?()
#else
        var rooms = read(key: roomsKey, as: [Room].self) ?? []
        var editable = room
        if editable.id?.isEmpty ?? true {
            editable.id = UUID().uuidString
        }

        if let index = rooms.firstIndex(where: { $0.id == editable.id }) {
            rooms[index] = editable
        } else {
            rooms.insert(editable, at: 0)
        }

        write(value: rooms, key: roomsKey)
        completion?()
#endif
    }

    func deleteRoom(_ roomId: String, completion: (() -> Void)? = nil) {
#if canImport(FirebaseFirestore)
        db.collection("rooms").document(roomId).delete { _ in completion?() }
#else
        var rooms = read(key: roomsKey, as: [Room].self) ?? []
        rooms.removeAll { $0.id == roomId }
        write(value: rooms, key: roomsKey)

        var windows = read(key: windowsKey, as: [WindowMeasurement].self) ?? []
        windows.removeAll { $0.roomId == roomId }
        write(value: windows, key: windowsKey)

        var floors = read(key: floorsKey, as: [FloorSpace].self) ?? []
        floors.removeAll { $0.roomId == roomId }
        write(value: floors, key: floorsKey)
        completion?()
#endif
    }

    func fetchWindows(roomId: String, completion: @escaping ([WindowMeasurement]) -> Void) {
#if canImport(FirebaseFirestore)
        db.collection("windows").whereField("roomId", isEqualTo: roomId).getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else {
                completion([])
                return
            }
            let windows = docs.compactMap { doc -> WindowMeasurement? in
                let data = doc.data()
                return WindowMeasurement(
                    id: doc.documentID,
                    roomId: data["roomId"] as? String ?? "",
                    name: data["name"] as? String ?? "",
                    widthMm: data["widthMm"] as? Double ?? 0,
                    heightMm: data["heightMm"] as? Double ?? 0,
                    selectedProductId: data["selectedProductId"] as? String,
                    selectedProductName: data["selectedProductName"] as? String,
                    selectedProductVariant: data["selectedProductVariant"] as? String,
                    panelCount: data["panelCount"] as? Int ?? 1,
                    photoBase64: data["photoBase64"] as? String,
                    includeInQuote: data["includeInQuote"] as? Bool ?? true
                )
            }
            completion(windows)
        }
#else
        let windows = (read(key: windowsKey, as: [WindowMeasurement].self) ?? []).filter { $0.roomId == roomId }
        completion(windows)
#endif
    }

    func saveWindow(_ window: WindowMeasurement, completion: (() -> Void)? = nil) {
#if canImport(FirebaseFirestore)
        if let id = window.id, !id.isEmpty {
            db.collection("windows").document(id).setData([
                "roomId": window.roomId,
                "name": window.name,
                "widthMm": window.widthMm,
                "heightMm": window.heightMm,
                "selectedProductId": window.selectedProductId as Any,
                "selectedProductName": window.selectedProductName as Any,
                "selectedProductVariant": window.selectedProductVariant as Any,
                "panelCount": window.panelCount,
                "photoBase64": window.photoBase64 as Any,
                "includeInQuote": window.includeInQuote
            ])
            completion?()
            return
        }
        var toSave = window
        let reference = db.collection("windows").document()
        toSave.id = reference.documentID
        reference.setData([
            "roomId": toSave.roomId,
            "name": toSave.name,
            "widthMm": toSave.widthMm,
            "heightMm": toSave.heightMm,
            "selectedProductId": toSave.selectedProductId as Any,
            "selectedProductName": toSave.selectedProductName as Any,
            "selectedProductVariant": toSave.selectedProductVariant as Any,
            "panelCount": toSave.panelCount,
            "photoBase64": toSave.photoBase64 as Any,
            "includeInQuote": toSave.includeInQuote
        ])
        completion?()
#else
        var windows = read(key: windowsKey, as: [WindowMeasurement].self) ?? []
        var editable = window
        if editable.id?.isEmpty ?? true {
            editable.id = UUID().uuidString
        }

        if let index = windows.firstIndex(where: { $0.id == editable.id }) {
            windows[index] = editable
        } else {
            windows.insert(editable, at: 0)
        }

        write(value: windows, key: windowsKey)
        completion?()
#endif
    }

    func deleteWindow(_ windowId: String, completion: (() -> Void)? = nil) {
#if canImport(FirebaseFirestore)
        db.collection("windows").document(windowId).delete { _ in completion?() }
#else
        var windows = read(key: windowsKey, as: [WindowMeasurement].self) ?? []
        windows.removeAll { $0.id == windowId }
        write(value: windows, key: windowsKey)
        completion?()
#endif
    }

    func fetchFloorSpaces(roomId: String, completion: @escaping ([FloorSpace]) -> Void) {
#if canImport(FirebaseFirestore)
        db.collection("floorSpaces").whereField("roomId", isEqualTo: roomId).getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else {
                completion([])
                return
            }
            let floors = docs.compactMap { doc -> FloorSpace? in
                let data = doc.data()
                return FloorSpace(
                    id: doc.documentID,
                    roomId: data["roomId"] as? String ?? "",
                    name: data["name"] as? String ?? "",
                    widthMm: data["widthMm"] as? Double ?? 0,
                    depthMm: data["depthMm"] as? Double ?? 0,
                    selectedProductId: data["selectedProductId"] as? String,
                    selectedProductName: data["selectedProductName"] as? String,
                    selectedProductVariant: data["selectedProductVariant"] as? String,
                    photoBase64: data["photoBase64"] as? String,
                    includeInQuote: data["includeInQuote"] as? Bool ?? true
                )
            }
            completion(floors)
        }
#else
        let floorSpaces = (read(key: floorsKey, as: [FloorSpace].self) ?? []).filter { $0.roomId == roomId }
        completion(floorSpaces)
#endif
    }

    func saveFloorSpace(_ floorSpace: FloorSpace, completion: (() -> Void)? = nil) {
#if canImport(FirebaseFirestore)
        if let id = floorSpace.id, !id.isEmpty {
            db.collection("floorSpaces").document(id).setData([
                "roomId": floorSpace.roomId,
                "name": floorSpace.name,
                "widthMm": floorSpace.widthMm,
                "depthMm": floorSpace.depthMm,
                "selectedProductId": floorSpace.selectedProductId as Any,
                "selectedProductName": floorSpace.selectedProductName as Any,
                "selectedProductVariant": floorSpace.selectedProductVariant as Any,
                "photoBase64": floorSpace.photoBase64 as Any,
                "includeInQuote": floorSpace.includeInQuote
            ])
            completion?()
            return
        }
        var toSave = floorSpace
        let reference = db.collection("floorSpaces").document()
        toSave.id = reference.documentID
        reference.setData([
            "roomId": toSave.roomId,
            "name": toSave.name,
            "widthMm": toSave.widthMm,
            "depthMm": toSave.depthMm,
            "selectedProductId": toSave.selectedProductId as Any,
            "selectedProductName": toSave.selectedProductName as Any,
            "selectedProductVariant": toSave.selectedProductVariant as Any,
            "photoBase64": toSave.photoBase64 as Any,
            "includeInQuote": toSave.includeInQuote
        ])
        completion?()
#else
        var floorSpaces = read(key: floorsKey, as: [FloorSpace].self) ?? []
        var editable = floorSpace
        if editable.id?.isEmpty ?? true {
            editable.id = UUID().uuidString
        }

        if let index = floorSpaces.firstIndex(where: { $0.id == editable.id }) {
            floorSpaces[index] = editable
        } else {
            floorSpaces.insert(editable, at: 0)
        }

        write(value: floorSpaces, key: floorsKey)
        completion?()
#endif
    }

    func deleteFloorSpace(_ floorSpaceId: String, completion: (() -> Void)? = nil) {
#if canImport(FirebaseFirestore)
        db.collection("floorSpaces").document(floorSpaceId).delete { _ in completion?() }
#else
        var floorSpaces = read(key: floorsKey, as: [FloorSpace].self) ?? []
        floorSpaces.removeAll { $0.id == floorSpaceId }
        write(value: floorSpaces, key: floorsKey)
        completion?()
#endif
    }

    private func read<T: Decodable>(key: String, as type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
