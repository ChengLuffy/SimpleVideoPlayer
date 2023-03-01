//
//  ViewController.swift
//  Example
//
//  Created by 成璐飞 on 2023/2/23.
//

import UIKit
import SimpleVideoPlayer
import AVFoundation

class ViewController: UIViewController, SimpleVideoPlayerDelegate {
    
    func playerViewController(_ playerViewController: SimpleVideoPlayer,
                              restoreUserInterfaceForPIPStopWithCompletionHandler
                              completionHandler: @escaping (Bool) -> Void) {
        restore(playerVC: playerViewController, completionHandler: completionHandler)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    @IBAction func playAction(_ sender: Any) {
//        guard let videoPath = Bundle.main.path(forResource: "Example", ofType: "mp4") else { return }
//        print(videoPath)
//        let playerVC = SimpleVideoPlayer(filePath: videoPath)
        let playerVC = SimpleVideoPlayer(urlStr: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")
        playerVC.delegate = self
        present(playerVC, animated: true)
    }
    
    func restore(playerVC: UIViewController, completionHandler: @escaping (Bool) -> Void) {
        if let presentedVC = presentedViewController {
            // 说明当前正在播放的界面还存在
            // 先关闭界面，再弹出播放界面
            presentedVC.dismiss(animated: false) { [weak self] in
                self?.present(playerVC, animated: false) {
                    completionHandler(true)
                }
            }
        } else {
            // 直接弹出播放界面
            present(playerVC, animated: false) {
                completionHandler(true)
            }
        }
    }
}
