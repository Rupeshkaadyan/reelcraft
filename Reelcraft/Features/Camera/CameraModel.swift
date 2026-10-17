import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Combine

final class CameraModel: NSObject, ObservableObject {
    @Published var isAvailable = true
    @Published var permissionDenied = false
    @Published var isRecording = false
    @Published var elapsed: Double = 0
    @Published var facing: AVCaptureDevice.Position = .back
    @Published var torchOn = false
    @Published var errorMessage: String?
    @Published var justRecorded: URL?

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "com.reelcraft.camera.session")
    private var timer: Timer?
    private var isConfigured = false

    func prepare() {
        guard !isConfigured else {
            start()
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configure()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        default:
            permissionDenied = true
        }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    private func configure() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            for input in self.session.inputs { self.session.removeInput(input) }

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.facing),
                  let videoInput = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(videoInput) else {
                DispatchQueue.main.async {
                    self.isAvailable = false
                    self.isConfigured = true
                }
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(videoInput)

            if let mic = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: mic),
               self.session.canAddInput(audioInput) {
                self.session.addInput(audioInput)
            }

            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
                self.movieOutput.movieFragmentInterval = .invalid
            }

            self.session.commitConfiguration()
            DispatchQueue.main.async {
                self.isConfigured = true
                self.isAvailable = true
            }
            self.session.startRunning()
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            }
            self.session.stopRunning()
        }
    }

    func toggleRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
            stopTimer()
            return
        }
        guard session.isRunning else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reelcraft-\(UUID().uuidString).mov")
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = facing == .front
            }
            connection.videoRotationAngle = 90
        }
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        elapsed = 0
        startTimer()
    }

    func flip() {
        guard !isRecording else { return }
        facing = facing == .back ? .front : .back
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            for input in self.session.inputs where input is AVCaptureDeviceInput {
                if let deviceInput = input as? AVCaptureDeviceInput, deviceInput.device.hasMediaType(.video) {
                    self.session.removeInput(deviceInput)
                }
            }
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.facing),
               let newInput = try? AVCaptureDeviceInput(device: camera),
               self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
            }
            self.session.commitConfiguration()
        }
    }

    func toggleTorch() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        torchOn.toggle()
        device.torchMode = torchOn ? .on : .off
        device.unlockForConfiguration()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsed += 0.1
            if self.elapsed >= 600 { self.toggleRecording() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension CameraModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopTimer()
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            self.justRecorded = outputFileURL
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}
