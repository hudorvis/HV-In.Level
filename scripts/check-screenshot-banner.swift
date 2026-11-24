import CoreGraphics
import Darwin
import Foundation
import ImageIO

guard CommandLine.arguments.count == 2,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let header = image.cropping(to: CGRect(x: image.width * 18 / 100, y: 0,
                                           width: image.width * 64 / 100, height: image.height * 6 / 100)),
      let context = CGContext(data: nil, width: 80, height: 16, bitsPerComponent: 8, bytesPerRow: 80,
                              space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
      let data = context.data else {
    fputs("Could not inspect screenshot header.\n", stderr)
    exit(1)
}

context.draw(header, in: CGRect(x: 0, y: 0, width: 80, height: 16))
let pixels = data.assumingMemoryBound(to: UInt8.self)
let brightPixels = (0..<(80 * 16)).reduce(0) { $0 + (pixels[$1] > 65 ? 1 : 0) }
// The dark In.Level header has a small bright wordmark. Simulator banners cover much more of it.
exit(brightPixels > 80 * 16 / 4 ? 3 : 0)
