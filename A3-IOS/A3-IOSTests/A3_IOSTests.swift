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

    @Test func excludedWindowDoesNotAddToQuote() async throws {
        let house = House(id: "h1", customerName: "Jamie", address: "99 Sample Rd")
        let room = Room(id: "r1", houseId: "h1", name: "Study")
        let product = Product(
            id: "p3",
            name: "Test Window",
            description: "",
            category: "window",
            imageUrl: nil,
            pricePerSqm: 80,
            minHeight: nil,
            maxHeight: nil,
            minWidth: nil,
            maxWidth: nil,
            maxPanelCount: nil,
            variants: []
        )
        let excludedWindow = WindowMeasurement(
            id: "w2",
            roomId: "r1",
            name: "Window 2",
            widthMm: 1200,
            heightMm: 1000,
            selectedProductId: "p3",
            selectedProductName: "Test Window",
            selectedProductVariant: nil,
            panelCount: 1,
            photoBase64: nil,
            includeInQuote: false
        )

        let summary = QuoteService.buildQuote(
            house: house,
            rooms: [room],
            windowsByRoomId: ["r1": [excludedWindow]],
            floorSpacesByRoomId: [:],
            productsById: ["p3": product],
            discountPercent: 0
        )

        #expect(summary.lineItems.isEmpty)
        #expect(summary.subtotal == 0)
        #expect(summary.total == 0)
    }

    @Test func missingProductDoesNotCreateQuoteLine() async throws {
        let house = House(id: "h1", customerName: "Taylor", address: "8 Missing Ln")
        let room = Room(id: "r1", houseId: "h1", name: "Office")
        let window = WindowMeasurement(
            id: "w3",
            roomId: "r1",
            name: "Window 3",
            widthMm: 1500,
            heightMm: 1200,
            selectedProductId: "missing-product",
            selectedProductName: "Unknown",
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
            productsById: [:],
            discountPercent: 0
        )

        #expect(summary.lineItems.isEmpty)
        #expect(summary.subtotal == 0)
        #expect(summary.total == 0)
    }

    @Test func excludedRoomDoesNotShowInQuote() async throws {
        let house = House(id: "h1", customerName: "Casey", address: "14 Quiet St")
        let room = Room(id: "r1", houseId: "h1", name: "Guest Room", includeInQuote: false)
        let product = Product(
            id: "p4",
            name: "Floor Sample",
            description: "",
            category: "floor",
            imageUrl: nil,
            pricePerSqm: 40,
            minHeight: nil,
            maxHeight: nil,
            minWidth: nil,
            maxWidth: nil,
            maxPanelCount: nil,
            variants: []
        )
        let floor = FloorSpace(
            id: "f3",
            roomId: "r1",
            name: "Guest Floor",
            widthMm: 2000,
            depthMm: 2000,
            selectedProductId: "p4",
            selectedProductName: "Floor Sample",
            selectedProductVariant: nil,
            photoBase64: nil,
            includeInQuote: true
        )

        let summary = QuoteService.buildQuote(
            house: house,
            rooms: [room],
            windowsByRoomId: [:],
            floorSpacesByRoomId: ["r1": [floor]],
            productsById: ["p4": product],
            discountPercent: 0
        )

        #expect(summary.lineItems.isEmpty)
        #expect(summary.subtotal == 0)
        #expect(summary.total == 0)
    }

    @Test func zeroDiscountKeepsSubtotalAndTotalSame() async throws {
        let house = House(id: "h1", customerName: "Morgan", address: "22 Equal St")
        let room = Room(id: "r1", houseId: "h1", name: "Media Room")
        let product = Product(
            id: "p5",
            name: "Media Floor",
            description: "",
            category: "floor",
            imageUrl: nil,
            pricePerSqm: 25,
            minHeight: nil,
            maxHeight: nil,
            minWidth: nil,
            maxWidth: nil,
            maxPanelCount: nil,
            variants: []
        )
        let floor = FloorSpace(
            id: "f4",
            roomId: "r1",
            name: "Main Floor",
            widthMm: 2000,
            depthMm: 1000,
            selectedProductId: "p5",
            selectedProductName: "Media Floor",
            selectedProductVariant: nil,
            photoBase64: nil,
            includeInQuote: true
        )

        let summary = QuoteService.buildQuote(
            house: house,
            rooms: [room],
            windowsByRoomId: [:],
            floorSpacesByRoomId: ["r1": [floor]],
            productsById: ["p5": product],
            discountPercent: 0
        )

        #expect(summary.subtotal == 50)
        #expect(summary.discountAmount == 0)
        #expect(summary.total == 50)
    }
}
