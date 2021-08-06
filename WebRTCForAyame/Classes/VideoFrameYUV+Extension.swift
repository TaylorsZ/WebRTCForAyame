//
//  VideoFrameYUV+Extension.swift
//  WebRTCForAyame
//
//  Created by Taylor on 2021/8/5.
//

import DJIWidget

extension VideoFrameYUV {
    
    func createPixelBuffer() -> CVPixelBuffer? {
        
        var initialPixelBuffer: CVPixelBuffer?
        let options:CFDictionary = [kCVPixelBufferCGImageCompatibilityKey:true,kCVPixelBufferCGBitmapContextCompatibilityKey:true] as CFDictionary;
        
        let _: CVReturn = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.width), Int(self.height), kCVPixelFormatType_420YpCbCr8Planar, options, &initialPixelBuffer)
        
        guard let pixelBuffer = initialPixelBuffer
              , CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess
        else {
            return nil
        }
        
        let yPlaneWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let yPlaneHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        
        let uPlaneWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let uPlaneHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        
        let vPlaneWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 2)
        let vPlaneHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 2)
        
        let yDestination = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        memcpy(yDestination, self.luma, yPlaneWidth * yPlaneHeight);
        
        let uDestination = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
        memcpy(uDestination, self.chromaB, uPlaneWidth * uPlaneHeight)

        let vDestination = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2)
        memcpy(vDestination, self.chromaR, vPlaneWidth * vPlaneHeight)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }
}

