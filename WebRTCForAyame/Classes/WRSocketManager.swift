//
//  WRSocketManager.swift
//  WebRTCForAyame
//
//  Created by Taylor on 2021/8/5.
//

import Foundation
import SocketRocket
//import Reachability

enum WRSocketConnectType:Int {
    /// 初始状态,未连接
    case `default`
    /// 已连接
    case  connect
    /// 连接后断开
    case  disConnect
}

protocol WRSocketDelegate {
    func wrSocketManager(wrSocketManager:WRSocketManager, connect connectType:WRSocketConnectType);
    func wrSocketManager(wrSocketManager:WRSocketManager, webSocketManagerDidReceiveMessage message:[String :Any]);
}

class WRSocketManager: NSObject {
    var isConnect:Bool = false;  //是否连接
    var connectType:WRSocketConnectType = .default;
    var delegate:WRSocketDelegate?;
    
    private var url:String = ""
    private var webSocket:SRWebSocket?;
    ///心跳定时器
    private let heartBeatTimer = "heartBeatTimer";
    /// 没有网络的时候检测网络定时器
    private let netWorkTestingTimer = "netWorkTestingTimer";
    ///重连时间
    private var reConnectTime:TimeInterval = 0;
    private var isActivelyClose:Bool = false;
    private static var _sharedInstance: WRSocketManager?
    
    class func shared() -> WRSocketManager {
        guard let instance = _sharedInstance else {
            _sharedInstance = WRSocketManager()
            return _sharedInstance!
        }
        return instance
    }
    
    private override init() {
        
    }
    override func copy() -> Any {
        return self // SingletonClass.shared
    }
    override func mutableCopy() -> Any {
        return self // SingletonClass.shared
    }
    //销毁单例对象
    class func destroy() {
        _sharedInstance = nil
    }
    @discardableResult
    func linkSocket(_ url:String) -> Bool {
        self.url = url;
        guard let socketURL = URL(string: url) else {
            Logger.debug("连接失败:地址无法转换成URL");
            return false;
        };
        let request = URLRequest(url: socketURL,cachePolicy: .useProtocolCachePolicy,timeoutInterval: 10);
        guard let socket = SRWebSocket(urlRequest: request) else {
            Logger.debug("连接失败:创建WebSocket失败");
            return false;
        }
        socket.delegate = self;
        socket.open();
        webSocket = socket;
        return true;
    }
    
    /// 发送消息
    /// - Parameter message: 消息
    func sendMessage(_ message:Any) {
        
        //        let reachability = try! Reachability();
        //        reachability.whenReachable = { reachability in
        //            if reachability.connection == .unavailable {
        //                print("Reachable via WiFi")
        //            } else {
        //                print("Reachable via Cellular")
        //            }
        //        }
        //        reachability.whenUnreachable = { _ in
        //            print("Not reachable")
        //        }
        //
        //        do {
        //            try reachability.startNotifier()
        //        } catch {
        //            print("Unable to start notifier")
        //        }
        //
        guard let socket = webSocket else {
            Logger.debug("发送失败")
            connectServer();
            return;
        }
        // 只有长连接OPEN开启状态才能调 send 方法，不然会Crash
        switch socket.readyState {
        case .OPEN:
            socket.send(message);
            break;
        case .CONNECTING:
            print("正在连接中，重连后会去自动同步数据");
        case .CLOSED:
            //调用 reConnectServer 方法重连,连接成功后 继续发送数据
            reConnectServer();
            break;
        case .CLOSING:
            //调用 reConnectServer 方法重连,连接成功后 继续发送数据
            reConnectServer();
            break;
        default:
            break;
        }
    }
   
    
    /// 重新连接
    func reConnectServer() {
        guard let socket = webSocket,socket.readyState != .OPEN else {
            return;
        }
        //重连10次 2^10 = 1024
        guard reConnectTime > 1024 else {
            reConnectTime = 0;
            return;
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + reConnectTime) {[weak self] in
            if socket.readyState == .OPEN && socket.readyState == .CONNECTING{
                return;
            }
            self?.connectServer();
            if self?.reConnectTime == 0{
                self?.reConnectTime = 2;
            }else{
                self?.reConnectTime *= 2;
            }
        }
        
    }
    ///关闭长连接
    func RMWebSocketClose() {
        isActivelyClose = false;
        isConnect = false;
        connectType = .default;
        webSocket?.close();
        webSocket = nil;
        
    }
    func connectServer() {
        isActivelyClose = false;
        
        webSocket?.delegate = nil;
        webSocket?.close();
        webSocket = nil;
        linkSocket(url)
    }
}

extension WRSocketManager :SRWebSocketDelegate{
    func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        connectType  =  .connect;
        delegate?.wrSocketManager(wrSocketManager: self, connect: .connect);
    }
    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        connectType  =  .disConnect;
        delegate?.wrSocketManager(wrSocketManager: self, connect: .disConnect);
    }
    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        Logger.debug("关闭")
        delegate?.wrSocketManager(wrSocketManager: self, connect: .disConnect)
    }
    func webSocket(_ webSocket: SRWebSocket!, didReceivePong pongPayload: Data!) {
        Logger.debug("接收到pong")
    }
    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        Logger.debug("获取到:\(String(describing: message))")
        guard let msg = message as? String ,let jsonData = msg.data(using: .utf8) else {
            return;
        }
        do {
            guard let dic = try JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as? [String:Any]  else {
                return;
            }
            delegate?.wrSocketManager(wrSocketManager: self, webSocketManagerDidReceiveMessage: dic)
        }catch{
            Logger.debug("webrtc解析失败:\(error.localizedDescription)")
        }
        
    }
    
}
