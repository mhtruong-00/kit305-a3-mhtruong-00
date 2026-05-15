import Testing
@testable import A3_IOS

struct A3_IOSTests {

    @Test func quoteCalculationIncludesDiscount() async throws {
        let house = House(id: "h1", customerName: "Sam", address: "10 Test St")
        let room = Room(id: "r1", houseId: "h1", name: "Living")
        let product = Product(
            id: "p1",
            name: "Window Product",
            description: "",
            category: "window",
            imageUrl: nil,
            pricePerSqm: 100,
            minHeight: nil,
            maxHeight: nil,
            minWidth: nil,
            maxWidth: nil,
            maxPanelCount: nil,
            variants: []
        )
        let window = WindowMeasurement(
            id: "w1",
            roomId: "r1",
            name: "Window 1",
            widthMm: 1000,
            heightMm: 1000,
            selectedProductId: "p1",
            selectedProductName: "Window Product",
            selectedProductVariant: nil,
            panelCount: 1,
            photoBase64: nil,
            includeInQuote: true
        )

        let summary = QuoteService.buildQuote(
            house: house,
            rooms: [room],
            windowsByRoomId: ["r1": [window]],
            floorSpacesByRoomId: [:],
            productsById: ["p1": product],
            discountPercent: 10
        )

        #expect(summary.subtotal == 100)
        #expect(summary.discountAmount == 10)
        #expect(summary.total == 90)
    }

    @Test func windowCompatibilityChecksMaxPanelCount() async throws {
        let product = Product(
            id: "p2",
            name: "Curtain",
            description: "",
            category: "window",
            imageUrl: nil,
            pricePerSqm: 10,
            minHeight: nil,
            maxHeight: nil,
            minWidth: nil,
            maxWidth: nil,
            maxPanelCount: 2,
            variants: []
        )

        let compatible = ProductAPIService.shared.isWindowProductCompatible(product: product, widthMm: 900, heightMm: 1400, panelCount: 2)
        let incompatible = ProductAPIService.shared.isWindowProductCompatible(product: product, widthMm: 900, heightMm: 1400, panelCount: 3)

        #expect(compatible)
        #expect(!incompatible)
    }

    @Test func quoteCalculationHandlesEdgeDiscountsAndMissingProducts() async throws {
        let house = House(id: "h1", customerName: "Alex", address: "1 Main St")
        let room = Room(id: "r1", houseId: "h1", name: "Bedroom")
        let pricedProduct = Product(
            id: "p1",
            name: "Floor Product",
            description: "",
            category: "floor",
            imageUrl: nil,
            pricePerSqm: 50,
            minHeight: nil,
            maxHeight: nil,
            minWidth: nil,
            maxWidth: nil,
            maxPanelCount: nil,
            variants: []
        )

        let includedFloor = FloorSpace(
            id: "f1",
            roomId: "r1",
            name: "Area A",
            widthMm: 1000,
            depthMm: 1000,
            selectedProductId: "p1",
            selectedProductName: "Floor Product",
            selectedProductVariant: nil,
            photoBase64: nil,
            includeInQuote: true
        )
        let excludedFloor = FloorSpace(
            id: "f2",
            roomId: "r1",
            name: "Area B",
            widthMm: 2000,
            depthMm: 2000,
            selectedProductId: "missing",
            selectedProductName: "Missing",
            selectedProductVariant: nil,
            photoBase64: nil,
            includeInQuote: false
        )

        let noDiscount = QuoteService.buildQuote(
            house: house,
            rooms: [room],
            windowsByRoomId: [:],
            floorSpacesByRoomId: ["r1": [includedFloor, excludedFloor]],
            productsById: ["p1": pricedProduct],
            discountPercent: 0
        )

        let fullDiscount = QuoteService.buildQuote(
            house: house,
            rooms: [room],
            windowsByRoomId: [:],
            floorSpacesByRoomId: ["r1": [includedFloor, excludedFloor]],
            productsById: ["p1": pricedProduct],
            discountPercent: 100
        )

        #expect(noDiscount.lineItems.count == 1)
        #expect(noDiscount.subtotal == 50)
        #expect(noDiscount.total == 50)
        #expect(fullDiscount.total == 0)
    }
}
