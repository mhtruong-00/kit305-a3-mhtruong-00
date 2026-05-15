import Foundation

struct WindowMeasurement: Codable, Identifiable {
    var id: String?
    var roomId: String
    var name: String
    var widthMm: Double
    var heightMm: Double
    var selectedProductId: String?
    var selectedProductName: String?
    var selectedProductVariant: String?
    var panelCount: Int
    var photoBase64: String?
    var includeInQuote: Bool

    init(
        id: String? = nil,
        roomId: String = "",
        name: String = "",
        widthMm: Double = 0,
        heightMm: Double = 0,
        selectedProductId: String? = nil,
        selectedProductName: String? = nil,
        selectedProductVariant: String? = nil,
        panelCount: Int = 1,
        photoBase64: String? = nil,
        includeInQuote: Bool = true
    ) {
        self.id = id
        self.roomId = roomId
        self.name = name
        self.widthMm = widthMm
        self.heightMm = heightMm
        self.selectedProductId = selectedProductId
        self.selectedProductName = selectedProductName
        self.selectedProductVariant = selectedProductVariant
        self.panelCount = panelCount
        self.photoBase64 = photoBase64
        self.includeInQuote = includeInQuote
    }
}
