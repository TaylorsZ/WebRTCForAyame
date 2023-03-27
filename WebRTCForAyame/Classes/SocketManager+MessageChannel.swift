//
//  SocketManager+MessageChannel.swift
//  WebRTCForAyame
//
//  Created by Taylor on 2021/8/5.
//

import UIKit
import WebRTC

extension WRSocketManager {
    
    /// 进入房间
    /// - Parameters:
    ///   - client: 客户ID
    ///   - room: 房间号
    func joinRoom(client:String?,room:String?) {
        guard let client = client,let room = room  else {
            Logger.debug("用户ID或房间号未获取到")
            return;
        }
        let dic = ["type": "register", "clientId": client,"roomId":room] as [String : Any];
        WRSocketManager.shared().sendMessage(convertToJsonData(dic));
    }
    
    /// 发送answer
    /// - Parameter sdp: sdp
    func sendAnswer(_ sdp:String) {
        let dic = ["type": "answer", "sdp": sdp] as [String : Any];
        WRSocketManager.shared().sendMessage(convertToJsonData(dic));
    }
    
    /// 发送offer
    /// - Parameter sdp: sdp
    func sendOffer(_ sdp:String) {
        let dic = ["type": "offer", "sdp": sdp] as [String : Any];
        WRSocketManager.shared().sendMessage(convertToJsonData(dic));
    }
    
    /// 发送 candidate
    /// - Parameter candidate: candidate
    func sendIceCandidate(_ candidate: RTCIceCandidate) {
        let dic =  ["type": "candidate","ice": ["candidate":candidate.sdp,"sdpMLineIndex":candidate.sdpMLineIndex,"sdpMid":candidate.sdpMid ?? "0"]] as [String : Any];
        WRSocketManager.shared().sendMessage(convertToJsonData(dic));
    }
    
    func sendPong() {
        let pong:[String:Any] = ["type":"pong"];
        WRSocketManager.shared().sendMessage(convertToJsonData(pong));
    }
   
    /// 将数据转换为json
    /// - Parameter dic: 原始数据
    /// - Returns: json字符串
    private func convertToJsonData(_ dic:Any) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dic, options: .prettyPrinted)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                return "";
            }
            Logger.debug("发送:\(jsonString)");
            return jsonString;
        } catch {
            Logger.error("转换失败：:\(error.localizedDescription)");

            return "";
        }
    }
}
