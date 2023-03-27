//
//  WebRTCManager.swift
//  WebRTCForAyame
//
//  Created by Taylor on 2021/8/5.
//

import UIKit
import WebRTC

 public protocol WebRTCManagerDelegate {
    
     func webRTCManager(manager:WebRTCForAyame ,peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]);
    func webRTCManager(manager:WebRTCForAyame ,peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel);
    func webRTCManager(manager:WebRTCForAyame ,peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream);
    func webRTCManager(manager:WebRTCForAyame ,peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream);
    func webRTCManager(manager:WebRTCForAyame ,peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState);
    
    func webRTCManager(manager:WebRTCForAyame ,didLeaveRoom connectid:String?);
    
}
public struct AdaptOutputFormat{
    var width:Int32 = 1280;
    var height:Int32 = 720;
    var fps:Int32  =  30;
    public init(width:Int32,height:Int32,fps:Int32) {
        self.width = width;
        self.height = height;
        self.fps = fps;
    }
}

/// 相机类型
public enum RTCCameraType {
    case file
    case device
    case dji
}

open class WebRTCForAyame: NSObject {
    public var adaptOutputFormat:AdaptOutputFormat = AdaptOutputFormat(width: 1280, height: 720, fps: 30);
    /// 文件名
    private var fileName:String = "";
    
    /// 摄像头 默认使用前摄像头
    private var devicePosition:AVCaptureDevice.Position  = .front;
    
    /// 视频采集类型
    private var cameraType:RTCCameraType = .device;
    public  var isDebug:Bool = true;
    private var server:String?;
    private var client:String?;
    private var room:String?
    
    private var  connectionDic:[String:RTCPeerConnection] = [:];
    private var  connectionIdArray:[String] = [];
    
    private var localStream:RTCMediaStream?;

    private var localAudioTrack:RTCAudioTrack?;
    private var localVideoTrack:RTCVideoTrack?;
    
    private var connectId:String?;
    private var iceServers:[RTCIceServer] = [];
    private var videoCapture:RTCVideoCapturer?
   
  
    open var delegate:WebRTCManagerDelegate?
    public var isLiving:Bool  =  false;
    private static var _sharedInstance: WebRTCForAyame?
    
    open class func shared() -> WebRTCForAyame {
        guard let instance = _sharedInstance else {
            _sharedInstance = WebRTCForAyame();
            
            return _sharedInstance!
        }
        return instance
    }
    
    private override init() {
        super.init();
        WRSocketManager.shared().delegate = self;
    }
    open override func copy() -> Any {
        return self // SingletonClass.shared
    }
    open override func mutableCopy() -> Any {
        return self // SingletonClass.shared
    }
    //销毁单例对象
    open class func destroy() {
        _sharedInstance = nil;
        
        WRSocketManager.shared().delegate = nil;
    }
    
    /// 点对点工厂
    private lazy var factory: RTCPeerConnectionFactory = {
        let encodeFac = RTCDefaultVideoEncoderFactory();
        let decodeFac = RTCDefaultVideoDecoderFactory();
        let arrCodecs = encodeFac.supportedCodecs();
        let info = arrCodecs[1];
        encodeFac.preferredCodec = info;
        let fac = RTCPeerConnectionFactory(encoderFactory: encodeFac, decoderFactory: decodeFac)
        return fac;
    }()
  
}
// MARK: - *************** 方法 ***************
extension WebRTCForAyame {
    
    
    /// 初始化，与服务器进行连接
    /// - Parameters:
    ///   - server: 服务器地址
    ///   - room: 房间号
    open func connectServer(server:String,room:String,client:String,iceServers:[[String:String]]? = nil) {
        
        self.server = server;
        self.room = room;
        self.client = client;
        if let ices = iceServers {
            do {
                self.iceServers = try fromJson(ices);
            } catch {
                Logger.debug(error.localizedDescription);
            }
        }
        WRSocketManager.shared().linkSocket(server);
        isLiving = true;
    }
    
 
    /// 退出房间
    open func exitRoom() {

        if let vc = videoCapture as? RTCCameraVideoCapturer  {
            vc.stopCapture {[weak self] in
                self?.videoCapture?.delegate = nil;
            };
        }
        if let vc = videoCapture as? RTCDJIVideoCapturer  {
            vc.stopCapture();
            videoCapture?.delegate = nil;
        }
        if let vc = videoCapture as? RTCFileVideoCapturer  {
            vc.stopCapture();
            videoCapture?.delegate = nil;
        }
       
        videoCapture = nil;
        closePeerConnection();
        isLiving = false;
    }
  
    
    /// 与目标建立连接
    /// - Parameter userId: 目标
    private func connect(userId:String) {
        
        ////设置SSL传输
        RTCPeerConnectionFactory.initialize();
        connectId = userId;
        //创建连接
        createPeerConnections();
        let stream = localStream ?? createLocalStream();
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {[weak self] in
            //添加
            self?.addStreams(stream);
            self?.createOffers();
        }
    }
    /**
     *  为所有连接添加流
     */
    private func addStreams(_ stream:RTCMediaStream) {
        
        //给每一个点对点连接，都加上本地流
        connectionDic.forEach { (key: String, value: RTCPeerConnection) in
            value.add(stream)
        }
    }
    private func createPeerConnections() {
        connectionIdArray.forEach { obj in
            //根据连接ID去初始化 RTCPeerConnection 连接对象
            let connection = createPeerConnection(connectionId: obj);
            //设置这个ID对应的 RTCPeerConnection对象
            connectionDic[obj] = connection;
        }
    }
    /// 创建点对点连接
    /// - Parameter connectionId: 连接人uuid
    /// - Returns: RTCPeerConnection
    private func createPeerConnection(connectionId:String) -> RTCPeerConnection {
        //用工厂来创建连接
        let configuration = RTCConfiguration();
        configuration.iceServers = iceServers;

        configuration.continualGatheringPolicy = .gatherContinually;
        //收集的策略类型，目前可供选择的有ALL(全部收集),NOHOST(不收集host类的策略信息),RELAY(只使用服务器的策略信息，简言之就是不通过P2P，只走服务端流量),NONE(不收集策略信息，目前作用未知)。一般来说，如果你想减少流量，那么就用ALL，WebRTC会在能打通P2P情况下使用P2P；如果你想要保证客户端的联通率，那么RELAY是你最好的选择。
        configuration.iceTransportPolicy  = .all;
        let constraints = creatPeerConnectionConstraint();
        let connection = factory.peerConnection(with: configuration, constraints: constraints, delegate: self);
        return connection;
    }
    private func createOffers() {
        connectionDic.forEach { (key: String, value: RTCPeerConnection) in
            createOffer(value);
        }
    }
    /// 为所有连接创建offer
    private func createOffer(_ peer:RTCPeerConnection) {
       
        //给每一个点对点连接，都去创建offer
        //        role = .caller;
        peer.offer(for: creatAnswerOrOfferConstraint(), completionHandler: {[weak self] (sdp, error) in
            guard let sdp = sdp else{
                Logger.debug("连接创建offer失败:\(error?.localizedDescription ?? "")")
                return;
            }
            peer.setLocalDescription(sdp, completionHandler: { (error1) in
                guard let err1 = error1 else{
                    self?.setSessionDescription(peer);
                    return;
                }
                Logger.debug("setLocalDescriptionError:\(err1.localizedDescription)")
                
            })
        })
    }
    
    /// 当一个远程或者本地的SDP被设置就会调用
    private func setSessionDescription(_ peerConnection:RTCPeerConnection) {
        let localSdp = peerConnection.localDescription?.sdp ?? ""
        //判断状态
        switch peerConnection.signalingState {
        case .haveRemoteOffer:
            //收到了远程点发来的offer，这个是进入房间的时候，尚且没人，来人就调到这里
            peerConnection.answer(for: creatAnswerOrOfferConstraint()) {[weak self] (sdp, error) in
                guard let sdp = sdp else{
                    Logger.debug("连接回应answer失败:\(error?.localizedDescription ?? "")")
                    return;
                }
                peerConnection.setLocalDescription(sdp, completionHandler: { (error1) in
                    guard let err1 = error1 else{
                        self?.setSessionDescription(peerConnection);
                        return;
                    }
                    Logger.debug("setLocalDescriptionError:\(err1.localizedDescription)")
                    
                })
            }
            break;
        case .haveLocalOffer:
            let type = peerConnection.localDescription!.type;
            //判断连接状态为本地发送offer
            if type == .answer {
                WRSocketManager.shared().sendAnswer(localSdp);
            }else if(type == .offer){
                WRSocketManager.shared().sendOffer(localSdp);
            }
            break;
        case .stable :
            let type = peerConnection.localDescription!.type;
            if type == .answer {
                WRSocketManager.shared().sendAnswer(localSdp);
            }
            break;
            
            
        default:
            break;
        }
    }
    
    /// 关闭peerConnection
    private func closePeerConnection() {
        connectId = nil;
       
        localStream = nil;
        connectionDic.forEach { (key: String, peerConnection: RTCPeerConnection) in
            peerConnection.close();
            peerConnection.delegate = nil;
        }
        connectionDic.removeAll();
        connectionIdArray.removeAll();
       
    }
    
    /// 设置自己静音
    /// - Parameter enable: 是否静音
    open func toggleMute(_ enable:Bool) {
        localAudioTrack?.isEnabled = enable;
    }
    /// 创建本地流
    @discardableResult
    private func createLocalStream() -> RTCMediaStream {
       
        let mStream = factory.mediaStream(withStreamId: "ARDAMS");
       
        //音频
        let aTruck = factory.audioTrack(withTrackId: "ARDAMSa0");
        mStream.addAudioTrack(aTruck);
        let videoSource = factory.videoSource();
        localAudioTrack = aTruck;
        

        videoSource.adaptOutputFormat(toWidth: adaptOutputFormat.width, height: adaptOutputFormat.height, fps: adaptOutputFormat.fps);
        Logger.debug("视频:\(adaptOutputFormat.width)")
        let vTrack = factory.videoTrack(with: videoSource, trackId: "ARDAMSv0");
        vTrack.isEnabled = true;
        
        switch cameraType {
        case .dji:
            let djiCapture = RTCDJIVideoCapturer(delegate: videoSource);
            djiCapture.start();
            videoCapture = djiCapture;
            break;
        case .device:
            guard
                //获取前置摄像头front 后置取back
                let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == devicePosition}),
                // choose highest res
                let format = (RTCCameraVideoCapturer.supportedFormats(for: frontCamera).sorted { (f1, f2) -> Bool in
                    let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
                    let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
                    return width1 < width2
                }).last,
                // choose highest fps
                let fps = (format.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else {
                return mStream
            }
            
            let deviceCapture = RTCCameraVideoCapturer(delegate: videoSource);
            videoCapture = deviceCapture;
            deviceCapture.startCapture(with: frontCamera, format: format, fps: Int(fps.maxFrameRate)) { error in
            }
            break;
        case .file:
            let fileCapture = RTCFileVideoCapturer(delegate: videoSource);
            videoCapture = fileCapture;
            fileCapture.startCapturing(fromFileNamed: fileName) { error in
                Logger.error("RTC采集文件失败:\(error.localizedDescription)");
            }
            break;
        }
        mStream.addVideoTrack(vTrack);
        return mStream;
    }
    
    /// 设置连接约束
    /// - Returns: 约束
    private func creatPeerConnectionConstraint() -> RTCMediaConstraints {
        return RTCMediaConstraints(mandatoryConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue,kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueTrue,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueTrue], optionalConstraints: nil);
        
    }
    
    /// 设置offer/answer的约束
    /// - Returns: 约束
    private func creatAnswerOrOfferConstraint() -> RTCMediaConstraints {
        return RTCMediaConstraints(mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueTrue,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueTrue], optionalConstraints: nil);
    }
    
   open func switchCamera(_ type:RTCCameraType,positon:AVCaptureDevice.Position? = nil,fileName:String? = nil) {
        cameraType = type;
        if type == .file && fileName == nil {
            Logger.error("请填写文件地址")
            return;
        }
        let name = fileName ?? ""
        self.fileName  = name;
        self.devicePosition = positon ?? .front;
        createLocalStream();
    }
  
}



extension WebRTCForAyame : RTCPeerConnectionDelegate{
    
    /// 当需要协商时调用，例如ICE重新启动
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        Logger.debug("当需要协商时调用，例如ICE重新启动")
    }
    /// 状态改变
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        Logger.debug("状态改变\(stateChanged.rawValue)")
        delegate?.webRTCManager(manager: self, peerConnection: peerConnection, didChange: stateChanged);
    }
    
    /// 获取远程视频流
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Logger.debug("获取远程视频流");
        delegate?.webRTCManager(manager: self, peerConnection: peerConnection, didAdd: stream);
    }
    ///删除某个视频流
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        Logger.debug("删除某个视频流");
        delegate?.webRTCManager(manager: self, peerConnection: peerConnection, didRemove: stream);
        
    }
    /// 在IceConnectionState更改时调用。
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Logger.debug("在IceConnectionState更改时调用。");
      
    }
    /// 在IceGatheringState更改时调用。
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Logger.debug("在IceGatheringState更改时调用。");
        
    }
    ///获取到新的candidate
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Logger.debug("获取到新的candidate");
        
        WRSocketManager.shared().sendIceCandidate(candidate);
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        Logger.debug("webrtc 移除")
        delegate?.webRTCManager(manager: self, peerConnection: peerConnection, didRemove: candidates);
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Logger.debug("didOpen dataChannel")
        delegate?.webRTCManager(manager: self, peerConnection: peerConnection, didOpen: dataChannel);
    }
}
extension WebRTCForAyame : WRSocketDelegate{
    func wrSocketManager(wrSocketManager: WRSocketManager, connect connectType: WRSocketConnectType) {
        if connectType == .connect {
            WRSocketManager.shared().joinRoom(client: client, room: room);
        }
    }
    func wrSocketManager(wrSocketManager: WRSocketManager, webSocketManagerDidReceiveMessage message: [String : Any]){
        
        Logger.debug("获取到:\(message)")
        
        guard let eventName = message["type"] as? String else {
            Logger.debug("接收格式不正确")
            return;
        }
        switch eventName {
        case "accept":
            //1.发送加入房间后的反馈
            // 创建连接
            guard let connectId = message["connectionId"] as? String else {
                return;
            }
            connectionIdArray.append(connectId)
            self.connectId = connectId;
            connect(userId: connectId);
            break;
            
            
        case "reject":
            //拒绝加入
            Logger.debug("拒绝加入")
            break;
            
        case "bye":
            //离开房间的事件
            Logger.debug("关闭视频");
            delegate?.webRTCManager(manager: self, didLeaveRoom: connectId);
            exitRoom();
            break;
            
        case "candidate":
            //4.接收到新加入的人发了ICE候选，（即经过ICEServer而获取到的地址）
            guard let dataDic = message["ice"] as? [String : Any] ,let sdpMid:String = dataDic["sdpMid"] as? String ,let sdpMLineIndex:Int32 = dataDic["sdpMLineIndex"] as? Int32 ,let sdp:String = dataDic["candidate"] as? String  else {
                return;
            }
            //生成远端网络地址对象
            let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid);
           
            //拿到当前对应的点对点连接
            let peerConnection = connectionDic[connectId!];
            
            //添加到点对点连接中
            peerConnection?.add(candidate)
            break;
            
        case "offer":
            //这个新加入的人发了个offer
            //回应offer
            guard let sdp:String = message["sdp"] as? String  else {
                return;
            }
            //根据类型和SDP 生成SDP描述对象
            let remoteSdp = RTCSessionDescription(type: .offer, sdp: sdp);
            //拿到当前对应的点对点连接
            guard let peerConnection = connectionDic[connectId!] else {
                return
            }
            peerConnection.setRemoteDescription(remoteSdp, completionHandler: {[weak self] (error) in
                self?.setSessionDescription(peerConnection);
            });
            break;
            
        case "answer":
            //回应offer
            guard let sdp:String = message["sdp"] as? String  else {
                return;
            }
            //拿到当前对应的点对点连接
            guard let peerConnection = connectionDic[connectId!] else {
                return
            }
            let remoteSdp = RTCSessionDescription(type: .answer, sdp: sdp);
            peerConnection.setRemoteDescription(remoteSdp, completionHandler: {[weak self] (error) in
                self?.setSessionDescription(peerConnection);
            });
            break;
        case "ping":
            Logger.debug("接收到心跳包");
            wrSocketManager.sendPong()
            break;
        default:
            break;
        }
        
    }
    private func fromJson(_ json:[[String:String]]) throws -> [RTCIceServer] {
        var ices:[RTCIceServer] = [];
        
        for item in json {
            if let url = item["url"] {
                if let username = item["username"] ,let credential = item["credential"] {
                    ices.append(RTCIceServer(urlStrings: [url], username: username, credential: credential));
                }else{
                    ices.append(RTCIceServer(urlStrings: [url]));
                }
            }else{
                throw NSError(domain: NSURLErrorFailingURLStringErrorKey, code: 1001, userInfo: [NSLocalizedDescriptionKey:"url地址不能为空"]);
            }
        }
        return ices;
    }
}


extension WebRTCForAyame {
    
    /// 设置所有用户静音
    /// - Parameter isEnabled: 开关
    public func setAllAudioEnabled(_ isEnabled:Bool) {
        
        localAudioTrack?.isEnabled = isEnabled;
//        connectionDic.forEach { (key: String, peerConnection: RTCPeerConnection) in
//            peerConnection.transceivers.forEach { transceiver in
//                if let track  = transceiver.sender.track as? RTCAudioTrack{
//                    track.isEnabled = isEnabled;
//                }
//            }
//        }
    }
    
    /// 外放开关
    /// - Parameter isEnabled: isEnabled
    /// - Returns: 结果
    @discardableResult
    public func enableSpeakerSession(_ isEnabled:Bool) -> Bool{
        let audioSession = AVAudioSession.sharedInstance();
        let category:AVAudioSession.Category = isEnabled ? .playback : .playAndRecord
        
        //设置为播放
        do {
            try audioSession.setCategory(category);
            try audioSession.setActive(true);
            return true;
        } catch {
            return false;
        }
    }
}



