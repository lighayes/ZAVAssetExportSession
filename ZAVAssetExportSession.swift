//
//  AMVideoNewEditor.swift
//  AMass
//
//  Created by lighayes on 2019/12/16.
//  Copyright © 2019 lighayes. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation

class ZAVAssetExportSession: NSObject{
    private let lock = NSLock()
    private var asset:AVAsset!
    private var videoTracks:[AVAssetTrack]=[]
    private var audioTracks:[AVAssetTrack]=[]
    //private var mixComposition:AVMutableComposition!
    private var assetReader:AVAssetReader!
    //private var audioReader:AVAssetReader!
    private var videoTrackOutput:AVAssetReaderVideoCompositionOutput!
    private var audioTrackOutput:AVAssetReaderAudioMixOutput!
    private let videoReadSetting:NSDictionary = [
        kCVPixelBufferPixelFormatTypeKey:kCVPixelFormatType_32BGRA,kCVPixelBufferIOSurfacePropertiesKey : NSDictionary(),
    ]
    private let audioReadSetting:NSDictionary = [AVFormatIDKey : kAudioFormatLinearPCM]
    private var assetWriter:AVAssetWriter!
    var videoWriterInput: AVAssetWriterInput!
    var audioWriterInput: AVAssetWriterInput!
    let compression:NSDictionary = [
        AVVideoPixelAspectRatioKey: [
            AVVideoPixelAspectRatioHorizontalSpacingKey: 1,
            AVVideoPixelAspectRatioVerticalSpacingKey: 1
        ],
        AVVideoMaxKeyFrameIntervalKey: 1,
        AVVideoAverageBitRateKey: 1280000
    ]
    ///下面是可以传入修改的属性
    //write setting
    var videoSettings: NSDictionary = [
        AVVideoCodecKey: AVVideoCodecH264 as AnyObject,
        AVVideoWidthKey: 1080 as AnyObject,
        AVVideoHeightKey: 1920 as AnyObject,
        AVVideoCompressionPropertiesKey: [
            AVVideoPixelAspectRatioKey: [
                AVVideoPixelAspectRatioHorizontalSpacingKey: 1,
                AVVideoPixelAspectRatioVerticalSpacingKey: 1
            ],
            AVVideoMaxKeyFrameIntervalKey: 1,
            AVVideoAverageBitRateKey: 1280000
        ]
    ]
    
    var audioSettings: [String: AnyObject] = [
        AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC),
        AVNumberOfChannelsKey: 1 as AnyObject,
        AVSampleRateKey: 22050 as AnyObject
    ]
    //private var videoPixelBufferAdaptor:AVAssetWriterInputPixelBufferAdaptor!
    //必须传入
    //不传入则创建失败
    var videoComposition:AVMutableVideoComposition?
    
    var outputURL:URL?
    
    var outputFileType:AVFileType?

    //进度
    var progress:Float = 0.0
    
    lazy var status = {()->AVAssetExportSession.Status in
        switch (self.assetWriter.status)
        {
        
        case AVAssetWriter.Status.unknown:
            return AVAssetExportSession.Status.unknown;
        case AVAssetWriter.Status.failed:
            return AVAssetExportSession.Status.failed;
        case AVAssetWriter.Status.completed:
            return AVAssetExportSession.Status.completed;
        case AVAssetWriter.Status.cancelled:
            return AVAssetExportSession.Status.cancelled;
        
        @unknown default:
            return AVAssetExportSession.Status.unknown
        }
    }
    
    init(asset:AVAsset) {
        self.asset = asset
       // return self
    }
    private func initReader(){
        do{
            try assetReader = AVAssetReader(asset: asset)
        }catch{
            print("reader build fail")
        }
        for i in asset.tracks(withMediaType: AVMediaType.video){
            videoTracks.append(i)
            print("add videotrack")
        }
        for i in asset.tracks(withMediaType: AVMediaType.audio){
            audioTracks.append(i)
            print("add audiotrack")
        }
        
        if videoTracks.count != 0{
        videoTrackOutput = AVAssetReaderVideoCompositionOutput(videoTracks: videoTracks, videoSettings: videoReadSetting as! [String : Any])
        videoTrackOutput.alwaysCopiesSampleData = false
        
        if assetReader.canAdd(videoTrackOutput){
            assetReader.add(videoTrackOutput)
        }else{
            print("cant add videoTrackOutput")
            }
            if (self.videoComposition != nil) {
                videoTrackOutput.videoComposition = self.videoComposition!
            }else{
                print("cant found videoCompostion")
            }
        }
        
        if audioTracks.count != 0{
        audioTrackOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: audioReadSetting as! [String : Any])
        audioTrackOutput.alwaysCopiesSampleData = false
        
        
        if assetReader.canAdd(audioTrackOutput){
            assetReader.add(audioTrackOutput)
        }else{
            print("cant add audioTrackOutput")
        }
        }
        assetReader.startReading()
    }
    
    private func initWriter(url:URL){
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: outputFileType!)
            
        }
        catch _ {
            
        }
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings as! [String : Any])
        videoWriterInput?.expectsMediaDataInRealTime = true
        // videoWriterInput?.transform = CGAffineTransformMakeRotation(CGFloat(M_PI / 2))
        if assetWriter.canAdd(videoWriterInput!) {
            assetWriter.add(videoWriterInput!)
        }
        if audioTracks.count != 0{
        audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings as! [String : Any])
        audioWriterInput?.expectsMediaDataInRealTime = false
        if assetWriter!.canAdd(audioWriterInput!) {
            assetWriter!.add(audioWriterInput!)
        }
        }
       
        
    }
    
    func exportAsynchronously(completionHandler handler: @escaping () -> Void){
        initReader()
        if (outputURL != nil&&outputFileType != nil) {
            initWriter(url: outputURL!)
        }else{
            print("url none OR outputFileType none")
            return
        }
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.zero)
        //let group = DispatchGroup()
        let videoInputQueue = dispatch_queue_serial_t(label: "videoInput")
        var videoCompleted = false
        var audioCompleted = false
        if (videoTracks.count > 0) {
            videoWriterInput.requestMediaDataWhenReady(on: videoInputQueue) {
                if self.encodesSamplesFrom(output: self.videoTrackOutput, input: self.videoWriterInput){
                    
                    self.lock.lock()
                    videoCompleted = true
                    if (audioCompleted)
                    {
                        self.finishWriting(completionHandler: handler)
                    }
                    self.lock.unlock()
                }
            }
        }else{
            videoCompleted = true
        }
        if (audioTracks.count > 0) {
            audioWriterInput.requestMediaDataWhenReady(on: videoInputQueue) {
                if self.encodesSamplesFrom(output: self.audioTrackOutput, input: self.audioWriterInput){
                    
                    self.lock.lock()
                    audioCompleted = true
                    if (videoCompleted)
                    {
                        self.finishWriting(completionHandler: handler)
                    }
                    self.lock.unlock()
                }
            }
        }else{
            audioCompleted = true
        }
    }
    
    private func encodesSamplesFrom(output:AVAssetReaderOutput,input:AVAssetWriterInput)->Bool{
//        while (input.isReadyForMoreMediaData)
//        {
//
//            var sampleBuffer = output.copyNextSampleBuffer()
//            if((sampleBuffer) != nil){
//                if(output == videoTrackOutput){
//                    let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer!)
//                    videoPixelBufferAdaptor.append(pixelBuffer!, withPresentationTime: CMSampleBufferGetDecodeTimeStamp(sampleBuffer!))
//                }else{
//                    input.append(sampleBuffer!)
//                }
//
//
//                //CFRelease(sampleBuffer)
//            }else{
//                input.markAsFinished()
//                return false
//            }
//        }
        while(assetReader.status != .reading){
            print(assetReader.status == .failed)
        }
        let duration = CMTimeGetSeconds(self.asset.duration);
        while(input.isReadyForMoreMediaData){
            var sampleBuffer = output.copyNextSampleBuffer()
            if((sampleBuffer) != nil){
                if assetReader.status != .reading||assetWriter.status != .writing{
                    print("not reading or not writing")
                    return false
                }
                let lastSamplePresentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer!);
                
                if(output == videoTrackOutput){
////                    let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer!)
////                    videoPixelBufferAdaptor.append(pixelBuffer!, withPresentationTime: CMSampleBufferGetDecodeTimeStamp(sampleBuffer!))
////                    if videoPixelBufferAdaptor.append(pixelBuffer!, withPresentationTime: CMSampleBufferGetDecodeTimeStamp(sampleBuffer!)){
////                        print("add video success")
////                    }else{
////                        print("add video fail")
////
////                    }
                    
                    self.progress = Float(duration == 0 ? 1 : CMTimeGetSeconds(lastSamplePresentationTime) / duration)/2;
                   
                    input.append(sampleBuffer!)
                }else{
                    self.progress = 0.5+Float(duration == 0 ? 1 : CMTimeGetSeconds(lastSamplePresentationTime) / duration)/2;
                
                    if input.append(sampleBuffer!){
                        //print("success")
                    }else{
                        return false
                        
                    }
                
                }
                 print(progress)
                
                //CFRelease(sampleBuffer)
            }else{
                input.markAsFinished()
                return true
            }
        }
        
        return false
    }
    
    private func finishWriting(completionHandler handler: @escaping () -> Void){
        assetWriter.finishWriting{
            if (self.assetWriter.status == .completed) {
                print("success");
                
            } else {
                if(self.assetWriter.status == .cancelled){
                    
//                    do {try FileManager.default.removeItem(at: self.outputURL!)
//                    }catch{
//
//                    }
                    return
                }
                if(self.assetReader.status == .failed){
                    self.assetWriter.cancelWriting()
                    print("read failed,error:\n")
                    print(self.assetReader.error)
                }
                if(self.assetWriter.status == .failed){
                    print("write failed,error:\n")
                    print(self.assetWriter.error)
//                    do {try
//                    FileManager.default.removeItem(at: self.outputURL!)
//                    }catch{
//                        
//                    }
                }
                
            }
            handler()
        }
    }
    
}
