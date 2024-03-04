//
//  ContentView.swift
//  SpatialVideoConverter
//
//  Created by Michael A Edgcumbe on 2/21/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State var leftEyeFileName:URL?
    @State var rightEyeFileName:URL?
    @State var stereoFileName:URL?
    @State var progress:Double = 0
    @State var widthString:Double = 8192
    @State var heightString:Double = 4096
    private let converter  = VideoConverter()

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Button {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.allowedContentTypes =  [UTType.quickTimeMovie]
                        panel.title = "Open Left Mono Video"
                        if panel.runModal() == .OK {
                            self.leftEyeFileName = panel.url
                        }
                    } label: {
                        self.leftEyeFileName == nil ?
                        Label("Open Left Mono Video", systemImage: "video") : Label(leftEyeFileName?.absoluteURL.lastPathComponent ?? "Open Left Mono Video", systemImage: "video")
                    }.padding(8)
                    Button {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.allowedContentTypes =  [UTType.quickTimeMovie]
                        panel.title = "Open Right Mono Video"
                        if panel.runModal() == .OK {
                            self.rightEyeFileName = panel.url
                        }
                    } label: {
                        self.rightEyeFileName == nil ?
                        Label("Open Right Mono Video", systemImage: "video") : Label(rightEyeFileName?.absoluteURL.lastPathComponent ?? "Open Right Mono Video", systemImage: "video")
                    }.padding(8)
                }
                
                HStack {
                    Text("Video width:")
                    TextField("Video width", value: $widthString, format:.number)
                    Text("Video height:")
                    TextField("Video height", value:$heightString, format:.number)
                }
                Spacer()
                if let leftEyeFileName = leftEyeFileName, let rightEyeFileName = rightEyeFileName {
                    Button {
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [UTType.quickTimeMovie]
                        panel.canCreateDirectories = true
                        panel.title = "Save Video"
                        if panel.runModal() == .OK {
                            self.stereoFileName = panel.url
                            Task { @MainActor in
                                do {
                                    try await converter.convert(rightEyeFileName: rightEyeFileName, leftEyeFileName: leftEyeFileName, stereoFileName: self.stereoFileName!, width:Int(widthString), height:Int(heightString))
                                } catch {
                                    print(error)
                                }
                            }
                        }
                    } label: {
                        Label("Save Stereo Video", systemImage: "square.and.arrow.down")
                    }
                    Spacer()
                    ProgressView("Progress: \(progress * 100)", value: progress)
                        .onChange(of: converter.processedTime) { oldValue, newValue in
                            progress = converter.processedTime.seconds / converter.duration.seconds
                        }
                    Spacer()
                }
                
            }
        }.frame(width: 640, height:480)

    }
}

#Preview {
    ContentView()
}
