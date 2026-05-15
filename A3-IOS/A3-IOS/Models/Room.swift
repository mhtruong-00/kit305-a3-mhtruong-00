import Foundation

struct Room: Codable, Identifiable {
    var id: String?
    var houseId: String
    var name: String
    var photoBase64: String?

    init(id: String? = nil, houseId: String = "", name: String = "", photoBase64: String? = nil) {
        self.id = id
        self.houseId = houseId
        self.name = name
        self.photoBase64 = photoBase64
    }
}
