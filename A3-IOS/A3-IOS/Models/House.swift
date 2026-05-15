import Foundation

struct House: Codable, Identifiable {
    var id: String?
    var customerName: String
    var address: String

    init(id: String? = nil, customerName: String = "", address: String = "") {
        self.id = id
        self.customerName = customerName
        self.address = address
    }
}
