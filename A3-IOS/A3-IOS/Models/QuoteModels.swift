import Foundation

struct QuoteLineItem {
    var id: String
    var title: String
    var details: String
    var areaSqm: Double
    var unitPrice: Double
    var lineTotal: Double
    var included: Bool
}

struct QuoteSummary {
    var lineItems: [QuoteLineItem]
    var subtotal: Double
    var discountPercent: Double
    var discountAmount: Double
    var total: Double
}
