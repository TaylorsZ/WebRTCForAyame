//
//  Logger.swift
//  WebRTCForAyame
//
//  Created by Taylor on 2021/8/5.
//

import UIKit

class Logger: NSObject {
    
    static func debug(_ items: Any..., separator: String = " ", terminator: String = "\n"){
        guard WebRTCForAyame.shared().isDebug == true else {
            return;
        }
        print(items)
    }
    static func error(_ items: Any..., separator: String = " ", terminator: String = "\n"){
//        guard WRSocketManager.shared().isDebug == true else {
//            return;
//        }
        print(items)
    }
}
