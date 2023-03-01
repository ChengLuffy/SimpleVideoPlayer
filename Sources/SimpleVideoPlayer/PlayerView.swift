//
//  PlayerView.swift
//  
//
//  Created by 成璐飞 on 2023/2/27.
//

import UIKit
import AVFoundation

class PlayerView: UIView {
    // Override the property to make AVPlayerLayer the view's backing layer.
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    // The associated player object.
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    // swiftlint:disable force_cast
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    // swiftlint:enable force_cast
}
