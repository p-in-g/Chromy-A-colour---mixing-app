import SwiftData
import SwiftUI
import UIKit

@Model
@available(iOS 17.0, *)
final class SpellBookRecord {
    @Attribute(.unique) var id: UUID
    var moodMessage: String
    var targetName: String?
    var date: Date
    var red: Double
    var green: Double
    var blue: Double
    var memoryImageData: Data?

    init(id: UUID = UUID(), moodMessage: String, targetName: String? = nil, date: Date = Date(), color: Color, memoryImageData: Data? = nil) {
        self.id = id
        self.moodMessage = moodMessage
        self.targetName = targetName
        self.date = date
        let rgb = SpellBookRecord.rgb(from: UIColor(color))
        self.red = rgb.r
        self.green = rgb.g
        self.blue = rgb.b
        self.memoryImageData = memoryImageData
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var memoryImage: UIImage? {
        guard let memoryImageData else { return nil }
        return UIImage(data: memoryImageData)
    }

    func updateMemoryImage(_ image: UIImage?) {
        guard let image else {
            memoryImageData = nil
            return
        }
        let resized = SpellBookRecord.resized(image: image, maxDimension: 1200)
        memoryImageData = resized.jpegData(compressionQuality: 0.82)
    }

    private static func rgb(from color: UIColor) -> (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private static func resized(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
