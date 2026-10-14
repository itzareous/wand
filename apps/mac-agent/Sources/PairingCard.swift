import CoreImage.CIFilterBuiltins
import SwiftUI

/// QR code + 6-digit code. Scanning the QR with the iPhone camera opens Wand and pairs.
struct PairingCard: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 24) {
            if let qr = Self.qrImage(agent.pairingURL.absoluteString) {
                Image(nsImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 148, height: 148)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white))
                    .accessibilityLabel("Pairing QR code")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Scan with your iPhone camera")
                    .font(.headline)
                Text("Or open Wand on your iPhone, tap this Mac and enter:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(agent.pairingCode)
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .tracking(4)
                    .textSelection(.enabled)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: agent.pairingCode)
                Text("Each code works once.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    static func qrImage(_ string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        let rep = NSCIImageRep(ciImage: output)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
