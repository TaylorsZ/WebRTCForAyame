//
//  RTCDJIVideoCapturer.swift
//  WebRTCForAyame
//
//  Created by Taylor on 2021/8/5.
//

import UIKit
import WebRTC
import DJIWidget
enum RTCDJIVideoCapturerState {
    case idle
    case run
}
class RTCDJIVideoCapturer: RTCVideoCapturer {
    /// 当前捕获器状态
    private var currentState : RTCDJIVideoCapturerState = .idle;
    
    /// frame计数
    var frameCounter:Int = 0;
    var encodeBeginTime:TimeInterval = 0;
    let DESIGNED_TIME_BASE = 90000;
    var previewer:DJIVideoPreviewer = DJIVideoPreviewer.instance();
    
    private let kNanosecondsPerSecond:Double = 1000000000;
    
    /// 开始捕获视频
    /// - Returns: 是否成功
    @discardableResult
    func start() -> Bool {
        Logger.debug("开始捕获视频数据");
        guard currentState == .idle else {
            return false;
        }
        currentState = .run;
        previewer.registFrameProcessor(self)
        return true;
    }
    
    
    ///  停止捕获
    /// - Returns: 是否成功
    @discardableResult
    func stopCapture() -> Bool {
        
        Logger.debug("结束捕获视频数据")
        currentState = .idle;
        previewer.unregistFrameProcessor(self);
        return true;
    }
    deinit {
        Logger.debug("\(self) 销毁")
    }
}
// MARK: - VideoFrameProcessor
extension RTCDJIVideoCapturer: VideoFrameProcessor {

    func videoProcessorEnabled() -> Bool {
        return true
    }
    func videoProcessFailedFrame(_ frame: UnsafeMutablePointer<VideoFrameH264Raw>!) {
        Logger.debug( "视频解析frame失败")
    }
    func videoProcessFrame(_ frame: UnsafeMutablePointer<VideoFrameYUV>!) {
        guard currentState == .run else {
            return;
        }
        
//        DLog(type: .debug, message: "yingjie")
        var pixelBuffer:CVPixelBuffer?
        let time = creatPresentationTime();
        if frame.pointee.cv_pixelbuffer_fastupload != nil {
            // 把 cv_pixelbuffer_fastupload 转换成 CVPixelBuffer 对象
            pixelBuffer = unsafeBitCast(frame.pointee.cv_pixelbuffer_fastupload, to: CVPixelBuffer.self)
        } else {
            // 自行构建 CVPixelBuffer 对象
            pixelBuffer = frame.pointee.createPixelBuffer()
        }
        guard let imageBuffer = pixelBuffer else {
            return;
        }
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: imageBuffer);
        let timeStampNs = time.seconds * kNanosecondsPerSecond;
//        let timeStampNs = frame.pointee.frame_info.assistInfo.timestamp;
        let videoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: ._0, timeStampNs: Int64(timeStampNs))
        delegate?.capturer(self, didCapture: videoFrame)
    }
    
    private func creatPresentationTime() -> CMTime {
        
        let current = CFAbsoluteTimeGetCurrent();
        if (frameCounter == 0) {
            self.encodeBeginTime = current;
        }
        var frameIntervel = DESIGNED_TIME_BASE / 30;
        let fps = DJIVideoPreviewer.instance()?.realTimeFrameRate ?? 0;
       
        
        if fps > 0 {
            frameIntervel = DESIGNED_TIME_BASE / Int(fps);
        }
        
        var presentationTimeStamp:CMTime = CMTime.invalid;
        if frameIntervel > 0 {
            presentationTimeStamp = CMTime(value: CMTimeValue(frameCounter) * CMTimeValue(frameIntervel), timescale: CMTimeScale(DESIGNED_TIME_BASE));
        }
        else {
            let encodeBeginTime = self.encodeBeginTime;
            let diff:CMTimeValue = CMTimeValue(current - encodeBeginTime);
            presentationTimeStamp = CMTime.init(value: diff * CMTimeValue(DESIGNED_TIME_BASE), timescale: CMTimeScale(DESIGNED_TIME_BASE));
        }
        frameCounter = frameCounter + 1;
        return presentationTimeStamp;
    }
}
