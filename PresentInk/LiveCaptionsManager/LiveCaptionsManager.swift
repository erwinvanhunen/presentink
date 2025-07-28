//
//  LiveCaptionsManager.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-28.
//

// PresentInk/Captions/LiveCaptionsManager.swift

import AVFoundation
import Cocoa
import Speech

class LiveCaptionsManager: NSObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(
        locale: Locale(identifier: Settings.shared.liveCaptionsLanguage)
    )
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    var onTextUpdate: ((String) -> Void)?

    private var lastUpdateTime: Date?
    private let pauseInterval: TimeInterval = 2.0

    func startCaptions() throws {

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            if status == .authorized {
                speechRecognizer?.defaultTaskHint = .unspecified
                speechRecognizer?.supportsOnDeviceRecognition = true
                DispatchQueue.main.async {
                    do {
                        let node = self.audioEngine.inputNode
                        let recordingFormat = node.outputFormat(forBus: 0)
                        node.removeTap(onBus: 0)
                        node.installTap(
                            onBus: 0,
                            bufferSize: 1024,
                            format: recordingFormat
                        ) { buffer, _ in
                            self.recognitionRequest?.append(buffer)
                        }
                        self.recognitionRequest =
                            SFSpeechAudioBufferRecognitionRequest()
                        self.recognitionRequest?.shouldReportPartialResults =
                            true
                        self.recognitionRequest?.requiresOnDeviceRecognition = true
                        self.recognitionTask = self.speechRecognizer?
                            .recognitionTask(with: self.recognitionRequest!) {
                                result,
                                error in
                                if let text = result?.bestTranscription
                                    .formattedString
                                {
                                    self.onTextUpdate?(text)
                                }
                            }

                        self.audioEngine.prepare()
                        try self.audioEngine.start()
                    } catch {
                        print("Failed to start audio engine: \(error)")
                    }
                }
            } else {
                print("Speech recognition not authorized: \(status.rawValue)")
            }
        }
    }

    func stopCaptions() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}
