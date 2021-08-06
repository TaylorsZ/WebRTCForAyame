//
//  ViewController.swift
//  WebRTCForAyame
//
//  Created by zhangs1992@126.com on 08/05/2021.
//  Copyright (c) 2021 zhangs1992@126.com. All rights reserved.
//

import UIKit
import WebRTCForAyame
import WebRTC

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        WebRTCForAyame.shared().isDebug = true;
        WebRTCForAyame.shared().switchCamera(.device,positon: .back);
  
        WebRTCForAyame.shared().adaptOutputFormat = AdaptOutputFormat(width: 1280, height: 720, fps: 30);
    }

    @IBAction func audioSwitch(_ sender: UISwitch) {
        WebRTCForAyame.shared().setAllAudioEnabled(sender.isOn);
//        WebRTCForAyame.shared().enableSpeakerSession(!sender.isOn);
        
    }
    @IBAction func switchTouched(_ sender: UISwitch) {
        
       
       
        if sender.isOn {
            WebRTCForAyame.shared().connectServer(server: "", room: "1234", client: "sbdgibo3eu78923674208")
        }else{
            WebRTCForAyame.shared().exitRoom();
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

