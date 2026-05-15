import Foundation

enum QuoteService {
    static func buildQuote(
        house: House,
        rooms: [Room],
        windowsByRoomId: [String: [WindowMeasurement]],
        floorSpacesByRoomId: [String: [FloorSpace]],
        productsById: [String: Product],
        discountPercent: Double
    ) -> QuoteSummary {
        var lineItems: [QuoteLineItem] = []

        for room in rooms {
            let roomId = room.id ?? ""
            for window in windowsByRoomId[roomId] ?? [] {
                guard window.includeInQuote else { continue }
                guard let productId = window.selectedProductId,
                      let product = productsById[productId] else { continue }

                let area = (window.widthMm / 1000.0) * (window.heightMm / 1000.0)
                let total = area * product.pricePerSqm
                lineItems.append(
                    QuoteLineItem(
                        id: window.id ?? UUID().uuidString,
                        title: "Window • \(window.name)",
                        details: room.name,
                        areaSqm: area,
                        unitPrice: product.pricePerSqm,
                        lineTotal: total,
                        included: true
                    )
                )
            }

            for floor in floorSpacesByRoomId[roomId] ?? [] {
                guard floor.includeInQuote else { continue }
                guard let productId = floor.selectedProductId,
                      let product = productsById[productId] else { continue }

                let area = (floor.widthMm / 1000.0) * (floor.depthMm / 1000.0)
                let total = area * product.pricePerSqm
                lineItems.append(
                    QuoteLineItem(
                        id: floor.id ?? UUID().uuidString,
                        title: "Floor • \(floor.name)",
                        details: room.name,
                        areaSqm: area,
                        unitPrice: product.pricePerSqm,
                        lineTotal: total,
                        included: true
                    )
                )
            }
        }

        let subtotal = lineItems.reduce(0) { $0 + $1.lineTotal }
        let safeDiscountPercent = min(max(discountPercent, 0), 100)
        let discountAmount = subtotal * (safeDiscountPercent / 100.0)
        let total = subtotal - discountAmount

        return QuoteSummary(
            lineItems: lineItems,
            subtotal: subtotal,
            discountPercent: safeDiscountPercent,
            discountAmount: discountAmount,
            total: total
        )
    }

    static func shareText(for house: House, summary: QuoteSummary) -> String {
        var lines = ["Home Quote", "\(csvField("House")),\(csvField(house.customerName)),\(csvField(house.address))", ""]
        lines.append("Item,Area(m2),Price/m2,Line Total")
        for item in summary.lineItems {
            lines.append("\(csvField(item.title)),\(String(format: "%.2f", item.areaSqm)),\(String(format: "%.2f", item.unitPrice)),\(String(format: "%.2f", item.lineTotal))")
        }
        lines.append("")
        lines.append("Subtotal,\(String(format: "%.2f", summary.subtotal))")
        lines.append("Discount %,\(String(format: "%.1f", summary.discountPercent))")
        lines.append("Discount Amount,\(String(format: "%.2f", summary.discountAmount))")
        lines.append("Total,\(String(format: "%.2f", summary.total))")
        return lines.joined(separator: "\n")
    }

    private static func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
