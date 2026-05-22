import SwiftUI
import AVFoundation
import AppKit

/// SwiftUI wrapper around an AVCaptureSession that decodes QR codes from the
/// default camera. Requires `NSCameraUsageDescription` in Info.plist and
/// camera permission at runtime.
struct QRScannerView: NSViewRepresentable {
    let onDecoded: (String) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSView {
        let container = ScannerContainer(onDecoded: onDecoded, onCancel: onCancel)
        container.start()
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        (nsView as? ScannerContainer)?.stop()
    }
}

final class ScannerContainer: NSView, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var didEmit = false

    private let onDecoded: (String) -> Void
    private let onCancel: () -> Void
    private let errorLabel = NSTextField(labelWithString: "")

    init(onDecoded: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onDecoded = onDecoded
        self.onCancel = onCancel
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        errorLabel.textColor = .white
        errorLabel.alignment = .center
        errorLabel.font = .systemFont(ofSize: 13)
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(errorLabel)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        preview?.frame = bounds
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.showError("Camera permission denied. Enable it in System Settings → Privacy & Security → Camera.")
                    return
                }
                self.configureSession()
            }
        }
    }

    func stop() {
        if session.isRunning { session.stopRunning() }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            showError("No camera available on this Mac.")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if session.canAddInput(input) { session.addInput(input) }

            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) { session.addOutput(output) }
            output.setMetadataObjectsDelegate(self, queue: .main)
            if output.availableMetadataObjectTypes.contains(.qr) {
                output.metadataObjectTypes = [.qr]
            }
            session.commitConfiguration()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = bounds
            self.layer?.addSublayer(layer)
            self.preview = layer

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        } catch {
            showError("Camera error: \(error.localizedDescription)")
        }
    }

    private func showError(_ msg: String) {
        errorLabel.stringValue = msg
        errorLabel.isHidden = false
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !didEmit else { return }
        for obj in metadataObjects {
            if let qr = obj as? AVMetadataMachineReadableCodeObject,
               qr.type == .qr,
               let s = qr.stringValue {
                didEmit = true
                session.stopRunning()
                onDecoded(s)
                return
            }
        }
    }
}
