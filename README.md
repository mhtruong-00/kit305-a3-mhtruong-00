# KIT305 Assignment 3 — iOS Application (Home Quote)

## Marker test setup
- **Recommended simulator/device:** iPhone 15 (or any iPhone simulator running iOS 17+)
- **Orientation:** Portrait
- **App target path:** `A3-IOS/A3-IOS`
- **Xcode project:** `A3-IOS/A3-IOS.xcodeproj`

## App summary
Home Quote is a native iOS (Swift + Storyboard/UIKit) interior design measurement and quoting app adapted from Assignment 2 Android functionality.

Implemented features include:
- houses list with search and CRUD
- house details with rooms list, search, and CRUD
- room details for room editing plus windows and floor spaces CRUD
- product selection from KIT305 product API
- window compatibility checks (size and panel constraints)
- photo library image selection for room/window/floor items (simulator-friendly)
- quote screen with itemised lines, include/exclude toggles, discount apply/clear, and share
- Firestore-ready persistence service with local fallback storage for environments where Firebase SDK is not linked yet

## Firebase note
This project is prepared for Firestore integration. Add your own `GoogleService-Info.plist` and Firebase packages in Xcode for live Firestore persistence.

## View Controllers and interrelation
- **`HouseListViewController`**
  - app entry screen inside a `UINavigationController`
  - manages house search + CRUD
  - opens house rooms (`HouseDetailViewController`) and quote (`QuoteViewController`)

- **`HouseDetailViewController`**
  - opened for a selected house
  - manages room search + CRUD for that house
  - opens room details (`RoomDetailViewController`) and quote (`QuoteViewController`)

- **`RoomDetailViewController`**
  - opened for a selected room
  - edits room name/photo
  - manages window and floor-space CRUD
  - opens `ProductListViewController` for product selection
  - opens `QuoteViewController` for quoting

- **`ProductListViewController`**
  - loads API products by category (`window` or `floor`)
  - supports search and variant selection
  - returns product selection to `RoomDetailViewController`

- **`QuoteViewController`**
  - loads rooms, windows, floor spaces, and product pricing
  - calculates itemised quote, discount, totals
  - allows include/exclude and sharing quote output text

## References
- KIT305 Assignment 3 specification and Assignment 2 specification on MyLO.
- KIT305 product API:
  - https://utasbot.dev/kit305_2026/product
  - https://utasbot.dev/kit305_2026/product?category=window
  - https://utasbot.dev/kit305_2026/product?category=floor
- Apple documentation:
  - UIKit: https://developer.apple.com/documentation/uikit
  - PHPickerViewController: https://developer.apple.com/documentation/photosui/phpickerviewcontroller
- Firebase docs:
  - https://firebase.google.com/docs/firestore

## Generative AI acknowledgement
- **Tool used:** GitHub Copilot (Copilot coding agent/chat)
- **Conversation reference:** this repository issue conversation for building the A3 iOS app migration.
- **How AI was used:**
  - planning iOS architecture from Android A2 features
  - generating and refining Swift models/services/controllers
  - implementing quote and validation logic
  - preparing README documentation structure
- All suggestions were reviewed and edited before keeping.
