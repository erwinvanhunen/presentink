// swift
//
//  ScreenRecorder.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-21.
//

import AVFoundation
import CoreGraphics
import ScreenCaptureKit
import VideoToolbox

enum RecordMode {
    case h264_sRGB
    case hevc_displayP3
}

class ScreenRecorder {
    private var micInput: AVCaptureDeviceInput?
    private let recordAudio: Bool
    
    private let videoSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.VideoSampleBufferQueue")
    private let audioSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.AudioSampleBufferQueue")
    
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput?
    
    private let streamOutput: StreamOutput
    private var stream: SCStream
    
    // Microphone capture (optional)
    private let audioSession: AVCaptureSession?
    private let audioDataOutput: AVCaptureAudioDataOutput?
    private let microphoneOutput: MicrophoneOutput?
    
    init(
        url: URL,
        displayID: CGDirectDisplayID,
        cropRect: CGRect?,
        mode: RecordMode,
        recordAudio: Bool
    ) async throws {
        self.recordAudio = recordAudio
        
        // Create AVAssetWriter for a QuickTime movie file
        self.assetWriter = try AVAssetWriter(url: url, fileType: .mp4)
        
        // MARK: AVAssetWriter setup (video)
        
        // Get size and pixel scale factor for display
        let displaySize = CGDisplayBounds(displayID).size
        
        // Scale factor (e.g. Retina 2x)
        let displayScaleFactor: Int
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            displayScaleFactor = mode.pixelWidth / mode.width
        } else {
            displayScaleFactor = 1
        }
        
        // Downsize to codec limits if needed
        let videoSize = downsizedVideoSize(
            source: cropRect?.size ?? displaySize,
            scaleFactor: displayScaleFactor,
            mode: mode
        )
        
        guard let assistant = AVOutputSettingsAssistant(preset: mode.preset) else {
            throw RecordingError("Can't create AVOutputSettingsAssistant")
        }
        assistant.sourceVideoFormat = try CMVideoFormatDescription(
            videoCodecType: mode.videoCodecType,
            width: videoSize.width,
            height: videoSize.height
        )
        
        guard var outputSettings = assistant.videoSettings else {
            throw RecordingError("AVOutputSettingsAssistant has no videoSettings")
        }
        outputSettings[AVVideoWidthKey] = videoSize.width
        outputSettings[AVVideoHeightKey] = videoSize.height
        outputSettings[AVVideoColorPropertiesKey] = mode.videoColorProperties
        if let videoProfileLevel = mode.videoProfileLevel {
            var compressionProperties: [String: Any] =
            outputSettings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
            compressionProperties[AVVideoProfileLevelKey] = videoProfileLevel
            outputSettings[AVVideoCompressionPropertiesKey] = compressionProperties as NSDictionary
        }
        
        // Video input
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        videoInput.expectsMediaDataInRealTime = true
        streamOutput = StreamOutput(videoInput: videoInput)
        
        guard assetWriter.canAdd(videoInput) else {
            throw RecordingError("Can't add video input to asset writer")
        }
        assetWriter.add(videoInput)
        
        // MARK: AVAssetWriter setup (audio - optional microphone AAC)
        
        var tmpAudioInput: AVAssetWriterInput? = nil
        if recordAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 48_000,
                AVEncoderBitRateKey: 192_000
            ]
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true
            
            guard assetWriter.canAdd(aInput) else {
                throw RecordingError("Can't add audio input to asset writer")
            }
            assetWriter.add(aInput)
            tmpAudioInput = aInput
        }
        audioInput = tmpAudioInput
        
        guard assetWriter.startWriting() else {
            if let error = assetWriter.error { throw error }
            throw RecordingError("Couldn't start writing to AVAssetWriter")
        }
        
        // MARK: Microphone capture session (optional)
        
        var tmpAudioSession: AVCaptureSession? = nil
        var tmpAudioDataOutput: AVCaptureAudioDataOutput? = nil
        var tmpMicrophoneOutput: MicrophoneOutput? = nil
        
        if recordAudio {
            let session = AVCaptureSession()
            let dataOutput = AVCaptureAudioDataOutput()
            guard let audioInput = audioInput else {
                throw RecordingError("Audio input missing while recordAudio is true")
            }
            let micOutput = MicrophoneOutput(audioInput: audioInput)
            
            session.beginConfiguration()
            guard let mic = AVCaptureDevice.default(for: .audio) else {
                throw RecordingError("No microphone device available")
            }
            let micInput = try AVCaptureDeviceInput(device: mic)
            if session.canAddInput(micInput) { session.addInput(micInput) }
            if session.canAddOutput(dataOutput) { session.addOutput(dataOutput) }
            dataOutput.setSampleBufferDelegate(micOutput, queue: audioSampleBufferQueue)
            session.commitConfiguration()
            self.micInput = micInput
            tmpAudioSession = session
            tmpAudioDataOutput = dataOutput
            tmpMicrophoneOutput = micOutput
        }
        
        audioSession = tmpAudioSession
        audioDataOutput = tmpAudioDataOutput
        microphoneOutput = tmpMicrophoneOutput
        
        // MARK: SCStream setup (screen)
        
        let sharableContent = try await SCShareableContent.current
        guard
            let display = sharableContent.displays.first(where: { $0.displayID == displayID })
        else {
            throw RecordingError("Can't find display with ID \(displayID) in sharable content")
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let configuration = SCStreamConfiguration()
        configuration.queueDepth = 6
        
        if let cropRect = cropRect {
            configuration.sourceRect = cropRect
            configuration.width = Int(cropRect.width) * displayScaleFactor
            configuration.height = Int(cropRect.height) * displayScaleFactor
        } else {
            configuration.width = Int(displaySize.width) * displayScaleFactor
            configuration.height = Int(displaySize.height) * displayScaleFactor
        }
        
        switch mode {
        case .h264_sRGB:
            configuration.pixelFormat = kCVPixelFormatType_32BGRA // 'BGRA'
            configuration.colorSpaceName = CGColorSpace.sRGB
        case .hevc_displayP3:
            configuration.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked // 'l10r'
            configuration.colorSpaceName = CGColorSpace.displayP3
        }
        
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(
            streamOutput,
            type: .screen,
            sampleHandlerQueue: videoSampleBufferQueue
        )
    }
    
    private func refreshMicrophoneSelectionToSystemDefault() throws {
        guard recordAudio, let session = audioSession else { return }
        
        session.beginConfiguration()
        if let existing = micInput {
            session.removeInput(existing)
            micInput = nil
        }
        guard let newDevice = AVCaptureDevice.default(for: .audio) else {
            session.commitConfiguration()
            throw RecordingError("No default audio input available")
        }
        let newInput = try AVCaptureDeviceInput(device: newDevice)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            micInput = newInput
        }
        session.commitConfiguration()
    }
    
    func start() async throws {
        // Start screen capture
        try await stream.startCapture()
        
        // AVAssetWriter timeline
        assetWriter.startSession(atSourceTime: .zero)
        streamOutput.sessionStarted = true
        
        if recordAudio {
            // ADD: pick up the current default device before starting the mic
            try? refreshMicrophoneSelectionToSystemDefault()
            microphoneOutput?.sessionStarted = true
            audioSession?.startRunning()
        }
    }
    
    //    func start() async throws {
    //        // Start screen capture
    //        try await stream.startCapture()
    //
    //        // Start writer timeline at t=0 and enable outputs
    //        assetWriter.startSession(atSourceTime: .zero)
    //        streamOutput.sessionStarted = true
    //
    //        if recordAudio {
    //            microphoneOutput?.sessionStarted = true
    //            audioSession?.startRunning()
    //        }
    //    }
    
    func stop() async throws {
        // Stop capture
        try await stream.stopCapture()
        if recordAudio {
            audioSession?.stopRunning()
        }
        
        // Repeat the last video frame at "now" to ensure expected length
        if let originalBuffer = streamOutput.lastSampleBuffer {
            let additionalTime =
            CMTime(seconds: ProcessInfo.processInfo.systemUptime, preferredTimescale: 100)
            - streamOutput.firstSampleTime
            let timing = CMSampleTimingInfo(
                duration: originalBuffer.duration,
                presentationTimeStamp: additionalTime,
                decodeTimeStamp: originalBuffer.decodeTimeStamp
            )
            let additionalSampleBuffer = try CMSampleBuffer(copying: originalBuffer, withNewTiming: [timing])
            videoInput.append(additionalSampleBuffer)
            streamOutput.lastSampleBuffer = additionalSampleBuffer
        }
        
        // End session at the max of last video/audio timestamps
        let lastVideoPTS = streamOutput.lastSampleBuffer?.presentationTimeStamp ?? .zero
        let lastAudioPTS = recordAudio
        ? (microphoneOutput?.lastSampleBuffer?.presentationTimeStamp ?? .zero)
        : .zero
        let endPTS = lastVideoPTS > lastAudioPTS ? lastVideoPTS : lastAudioPTS
        assetWriter.endSession(atSourceTime: endPTS)
        
        // Finish writing
        videoInput.markAsFinished()
        audioInput?.markAsFinished()
        await assetWriter.finishWriting()
    }
    
    private class StreamOutput: NSObject, SCStreamOutput {
        let videoInput: AVAssetWriterInput
        var sessionStarted = false
        var firstSampleTime: CMTime = .zero
        var lastSampleBuffer: CMSampleBuffer?
        
        init(videoInput: AVAssetWriterInput) {
            self.videoInput = videoInput
        }
        
        func stream(
            _ stream: SCStream,
            didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
            of type: SCStreamOutputType
        ) {
            guard sessionStarted, sampleBuffer.isValid else { return }
            
            // Validate frame completeness
            if type == .screen {
                guard
                    let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                    let attachments = attachmentsArray.first,
                    let statusRaw = attachments[SCStreamFrameInfo.status] as? Int,
                    let status = SCFrameStatus(rawValue: statusRaw),
                    status == .complete
                else { return }
            }
            
            switch type {
            case .screen:
                if videoInput.isReadyForMoreMediaData {
                    if firstSampleTime == .zero {
                        firstSampleTime = sampleBuffer.presentationTimeStamp
                    }
                    let lastSampleTime = sampleBuffer.presentationTimeStamp - firstSampleTime
                    lastSampleBuffer = sampleBuffer
                    
                    let timing = CMSampleTimingInfo(
                        duration: sampleBuffer.duration,
                        presentationTimeStamp: lastSampleTime,
                        decodeTimeStamp: sampleBuffer.decodeTimeStamp
                    )
                    if let retimed = try? CMSampleBuffer(copying: sampleBuffer, withNewTiming: [timing]) {
                        videoInput.append(retimed)
                    } else {
                        print("Couldn't copy CMSampleBuffer, dropping frame")
                    }
                } else {
                    print("AVAssetWriterInput isn't ready, dropping frame")
                }
            case .audio, .microphone:
                break
            @unknown default:
                break
            }
        }
    }
    
    private class MicrophoneOutput: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
        let audioInput: AVAssetWriterInput
        var sessionStarted = false
        var firstSampleTime: CMTime = .zero
        var lastSampleBuffer: CMSampleBuffer?
        
        init(audioInput: AVAssetWriterInput) {
            self.audioInput = audioInput
        }
        
        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            guard sessionStarted, sampleBuffer.isValid else { return }
            guard audioInput.isReadyForMoreMediaData else { return }
            
            if firstSampleTime == .zero {
                firstSampleTime = sampleBuffer.presentationTimeStamp
            }
            let relativePTS = sampleBuffer.presentationTimeStamp - firstSampleTime
            
            let timing = CMSampleTimingInfo(
                duration: sampleBuffer.duration,
                presentationTimeStamp: relativePTS,
                decodeTimeStamp: sampleBuffer.decodeTimeStamp
            )
            if let retimed = try? CMSampleBuffer(copying: sampleBuffer, withNewTiming: [timing]) {
                lastSampleBuffer = retimed
                audioInput.append(retimed)
            } else {
                print("Couldn't copy audio CMSampleBuffer, dropping sample")
            }
        }
    }
}

private func downsizedVideoSize(
    source: CGSize,
    scaleFactor: Int,
    mode: RecordMode
) -> (width: Int, height: Int) {
    let maxSize = mode.maxSize
    
    let w = source.width * Double(scaleFactor)
    let h = source.height * Double(scaleFactor)
    let r = max(w / maxSize.width, h / maxSize.height)
    
    return r > 1
    ? (width: Int(w / r), height: Int(h / r))
    : (width: Int(w), height: Int(h))
}

struct RecordingError: Error, CustomDebugStringConvertible {
    var debugDescription: String
    init(_ debugDescription: String) {
        self.debugDescription = debugDescription
    }
}

// Extension properties for values that differ per record mode
extension RecordMode {
    var preset: AVOutputSettingsPreset {
        switch self {
        case .h264_sRGB: return .preset3840x2160
        case .hevc_displayP3: return .hevc7680x4320
        }
    }
    
    var maxSize: CGSize {
        switch self {
        case .h264_sRGB: return CGSize(width: 4096, height: 2304)
        case .hevc_displayP3: return CGSize(width: 7680, height: 4320)
        }
    }
    
    var videoCodecType: CMFormatDescription.MediaSubType {
        switch self {
        case .h264_sRGB: return .h264
        case .hevc_displayP3: return .hevc
        }
    }
    
    var videoColorProperties: NSDictionary {
        switch self {
        case .h264_sRGB:
            return [
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ]
        case .hevc_displayP3:
            return [
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ]
        }
    }
    
    var videoProfileLevel: CFString? {
        switch self {
        case .h264_sRGB:
            return nil
        case .hevc_displayP3:
            return nil
        }
    }
}
