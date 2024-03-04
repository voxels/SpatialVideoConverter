//
//  VideoConverter.swift
//  SpatialVideoConverter
//
//  Created by Michael A Edgcumbe on 2/21/24.
//

import Foundation
import AVFoundation
import VideoToolbox
import CoreVideo

public enum VideoConverterError : Error {
    case MissingAssets
    case MissingAssetReader
    case AssetReading
    case ImageBuffers
}

@Observable
open class VideoConverter {
    
    public var processedFrameCount:Int = 0
    public var processedTime:CMTime = CMTime(seconds: 0, preferredTimescale: 10000000)
    public var duration:CMTime = CMTime(seconds: 0, preferredTimescale: 10000000)
    var leftAsset:AVAsset?
    var rightAsset:AVAsset?
    var leftAssetReader:AVAssetReader?
    var rightAssetReader:AVAssetReader?
    var leftImageGenerator:AVAssetImageGenerator?
    var rightImageGenerator:AVAssetImageGenerator?
    var assetWriter:AVAssetWriter?
    var countFrames:Double = 0
    public func
    convert(rightEyeFileName:URL, leftEyeFileName:URL, stereoFileName:URL, width:Int, height:Int) async throws {
        
        assetWriter = try AVAssetWriter(url: stereoFileName, fileType: .mov)
        
        let settings = AVOutputSettingsAssistant(preset: .mvhevc1440x1440)
        var videoSettings = settings?.videoSettings
        let compressionProperties = videoSettings![AVVideoCompressionPropertiesKey] as! NSMutableDictionary
        compressionProperties[kVTCompressionPropertyKey_MVHEVCVideoLayerIDs] = [0, 1] as CFArray
        compressionProperties[kCMFormatDescriptionExtension_HorizontalFieldOfView] = 360_000
        compressionProperties[kVTCompressionPropertyKey_HorizontalDisparityAdjustment] = 200
        videoSettings?[AVVideoWidthKey] = width
        videoSettings?[AVVideoHeightKey] = height
 
        videoSettings?[AVVideoCompressionPropertiesKey] =  compressionProperties
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings
        )
        
        assetWriter?.add(input)
        
        
        self.rightAsset = AVAsset(url: rightEyeFileName)
        self.leftAsset = AVAsset(url: leftEyeFileName)
        guard let rightAsset = rightAsset, let leftAsset = leftAsset else {
            throw VideoConverterError.MissingAssets
        }
        
        self.duration = try await rightAsset.load(.duration)
        
        self.rightAssetReader = try AVAssetReader(asset: rightAsset)
        self.leftAssetReader = try AVAssetReader(asset: leftAsset)
        guard let rightAssetReader = rightAssetReader, let leftAssetReader = leftAssetReader  else {
            throw VideoConverterError.MissingAssetReader
        }
        
        let outputSettings =  [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_422YpCbCr10]
        let adaptor = AVAssetWriterInputTaggedPixelBufferGroupAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: outputSettings)
        
        let rightOutput = try await AVAssetReaderTrackOutput(track: rightAsset.loadTracks(withMediaType: .video).first!, outputSettings:outputSettings as [String : Any])
        let leftOutput = try await AVAssetReaderTrackOutput(track: leftAsset.loadTracks(withMediaType: .video).first!, outputSettings:outputSettings)
        
        
        rightAssetReader.add(rightOutput)
        leftAssetReader.add(leftOutput)
        
        if rightAssetReader.startReading(), leftAssetReader.startReading() {
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)
            
                let loop = true
            while loop {
                if input.isReadyForMoreMediaData {
                    let rightSampleBuffer = rightOutput.copyNextSampleBuffer()
                    let leftSampleBuffer = leftOutput.copyNextSampleBuffer()
                    
                    guard let rightSampleBuffer = rightSampleBuffer, let leftSampleBuffer = leftSampleBuffer else {
                        input.markAsFinished()
                        assetWriter?.endSession(atSourceTime: duration)
                        assetWriter?.finishWriting(completionHandler: {
                            self.processedTime = self.duration
                            print("finished writing")
                        })
                        countFrames = 0
                        return
                    }
                    
                    requestData(adaptor: adaptor, input: input, rightOutput: rightOutput, leftOutput: leftOutput, rightSampleBuffer: rightSampleBuffer, leftSampleBuffer: leftSampleBuffer)
                }
                
                else {
                    continue
                }
            }
        }
    }
    
    public func requestData(adaptor: AVAssetWriterInputTaggedPixelBufferGroupAdaptor, input:AVAssetWriterInput, rightOutput:AVAssetReaderTrackOutput, leftOutput:AVAssetReaderTrackOutput, rightSampleBuffer:CMSampleBuffer, leftSampleBuffer:CMSampleBuffer) {
        
        
        guard let leftImage = CMSampleBufferGetImageBuffer(leftSampleBuffer), let rightImage = CMSampleBufferGetImageBuffer(rightSampleBuffer) else {
            print("No Image Buffers")
            return
        }
        CVPixelBufferLockBaseAddress(leftImage, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(rightImage, CVPixelBufferLockFlags.readOnly)
        
        let left = CMTaggedBuffer(tags: [.stereoView(.leftEye), .videoLayerID(0)], pixelBuffer: leftImage )
        let right = CMTaggedBuffer(tags: [.stereoView(.rightEye), .videoLayerID(1)], pixelBuffer: rightImage)
        
        if adaptor.appendTaggedBuffers([left, right], withPresentationTime:leftSampleBuffer.presentationTimeStamp) {
            countFrames += 1
            processedFrameCount = Int(countFrames)
            print("adapted frame \(countFrames)")
        } else {
            print("did not adapt frame \(countFrames)")
        }
        let timestamp = leftSampleBuffer.presentationTimeStamp
        
        Task { @MainActor in
            processedTime = timestamp
        }
        
        CVPixelBufferUnlockBaseAddress(leftImage, .readOnly)
        CVPixelBufferUnlockBaseAddress(rightImage, .readOnly)
    }
}
