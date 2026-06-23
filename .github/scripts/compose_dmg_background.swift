// Regenerates the macOS DMG window background committed at data/dmg-background.png.
//
// The build/release workflows do NOT run this, they ship the pre-rendered PNG
// directly (see the "Create DMG" step). This script is kept in the repo so the
// background can be regenerated whenever the source art or layout changes.
//
// Note: This could be added a prestep in CI to generate this dynamically
//
// It composites, onto a 750x450 canvas (the DMG window size in points):
//   1. the ocean background,
//   2. an island the Applications folder sits on,
//   3. the yellow Archipelago "progressive" block arrow pointing app -> Applications,
//   4. translucent plates behind the two icon labels (the Finder label text is
//      always black, so the plates keep it readable over the blue water).
//
// The icon/window geometry here must stay in sync with the create-dmg flags in
// .github/workflows/build.yml and release.yml (window-size, icon positions, icon-size).
//
// Usage (run from the repo root):
//   swift .github/scripts/compose_dmg_background.swift
// Optional overrides: [ocean.png] [island.png] [out.png]

import AppKit
import Foundation

let args = CommandLine.arguments
let oceanPath  = args.count > 1 ? args[1] : "WebHostLib/static/static/backgrounds/ocean.png"
let islandPath = args.count > 2 ? args[2] : "WebHostLib/static/static/button-images/island-button-b.png"
let outPath    = args.count > 3 ? args[3] : "data/dmg-background.png"

guard let ocean = NSImage(contentsOfFile: oceanPath) else { fatalError("missing ocean: \(oceanPath)") }
guard let island = NSImage(contentsOfFile: islandPath) else { fatalError("missing island: \(islandPath)") }

let W: CGFloat = 750, H: CGFloat = 450      // DMG window size in points

// Icon layout (top-left origin, matches the create-dmg --icon / --app-drop-link flags)
let iconSize: CGFloat = 128
let appCenter  = CGPoint(x: 210, y: 170)    // Archipelago.app
let applCenter = CGPoint(x: 540, y: 170)    // Applications drop link

// Island: wider than the 128px Applications folder, dropped below it so the
// base of the folder lands in the green interior of the island.
let islandW: CGFloat = 320
let islandCenterTop = CGPoint(x: 540, y: applCenter.y + 32)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

// convert a top-left y (the coordinate system create-dmg uses) to AppKit's bottom-left y
func flip(_ yTop: CGFloat) -> CGFloat { H - yTop }

// 1) ocean background scaled to the window size
ocean.draw(in: NSRect(x: 0, y: 0, width: W, height: H))

// 2) island the Applications folder rests on
let aspect = island.size.height / island.size.width
let islandH = islandW * aspect
island.draw(in: NSRect(x: islandCenterTop.x - islandW / 2,
                       y: flip(islandCenterTop.y) - islandH / 2,
                       width: islandW, height: islandH))

// 3) solid yellow block arrow (the Archipelago "progressive" arrow shape, #FFF041,
//    rotated to point right) in the open water between the app and the island
func arrow(centerX cx: CGFloat, centerY cy: CGFloat) {
    let hh: CGFloat = 24      // head half-height
    let hs: CGFloat = 12      // shaft half-height
    let tip  = cx + 28        // arrow tip (right)
    let neck = cx + 2         // where the triangular head meets the shaft
    let back = cx - 28        // shaft tail (left)
    let p = NSBezierPath()
    p.move(to: NSPoint(x: tip,  y: flip(cy)))
    p.line(to: NSPoint(x: neck, y: flip(cy - hh)))
    p.line(to: NSPoint(x: neck, y: flip(cy - hs)))
    p.line(to: NSPoint(x: back, y: flip(cy - hs)))
    p.line(to: NSPoint(x: back, y: flip(cy + hs)))
    p.line(to: NSPoint(x: neck, y: flip(cy + hs)))
    p.line(to: NSPoint(x: neck, y: flip(cy + hh)))
    p.close()
    NSColor(red: 1.0, green: 240 / 255.0, blue: 65 / 255.0, alpha: 1).setFill()  // #FFF041
    p.fill()
}
arrow(centerX: 330, centerY: applCenter.y)

// 4) translucent plates behind the (always-black) Finder label text
func plate(centerX cx: CGFloat, iconCenterYTop iy: CGFloat, width w: CGFloat) {
    let h: CGFloat = 28
    let topY = iy + iconSize / 2 + 6          // just under the icon, where Finder draws the label
    let r = NSRect(x: cx - w / 2, y: flip(topY) - h, width: w, height: h)
    NSColor(white: 1.0, alpha: 0.80).setFill()
    NSBezierPath(roundedRect: r, xRadius: h / 2, yRadius: h / 2).fill()
}
plate(centerX: appCenter.x,  iconCenterYTop: appCenter.y,  width: 135)   // "Archipelago"
plate(centerX: applCenter.x, iconCenterYTop: applCenter.y, width: 140)   // "Applications"

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) \(Int(W))x\(Int(H))")
