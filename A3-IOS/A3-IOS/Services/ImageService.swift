import Foundation
import UIKit

enum ImageService {
    static func toBase64(_ image: UIImage?) -> String? {
        guard let image, let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        return data.base64EncodedString()
    }

    static func fromBase64(_ text: String?) -> UIImage? {
        guard let text, let data = Data(base64Encoded: text) else { return nil }
        return UIImage(data: data)
    }
}
