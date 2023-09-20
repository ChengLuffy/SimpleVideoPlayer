//
//  PlayerMaskView.swift
//  
//
//  Created by 成璐飞 on 2023/2/24.
//

import UIKit
import AVKit
import Combine

protocol PlayerMaskViewDelegate: AnyObject {
    func closePlayer()
    func enterPiPMode()
    func pasueAction()
    func playAction()
    func seekTo(time: CMTime)
    func toggleFullScreen()
    func toggleLockInterface(isLocked: Bool)
    func changeSpeed(_ speed: Float)
    func goforward()
    func gobackward()
    func getPlayerStatus() -> PlayerStatus
}

class PlayerMaskView: UIView {
    
    // MARK: - 开放属性
    
    /// 各种按钮的响应事件代理
    weak var delegate: PlayerMaskViewDelegate?
    /// 进度条拖动动作需要视频准备好
    var videoIsReady = 0 {
        didSet {
            if videoIsReady == 1 {
                loadingView.stopAnimating()
                centerBtn.isHidden = false
                goforwardBtn.isHidden = false
                gobackwardBtn.isHidden = false
                setNextDismissTime()
                if delegate?.getPlayerStatus() != .pause {
                    delegate?.playAction()
                }
            } else if videoIsReady == 0 {
                loadingView.startAnimating()
                centerBtn.isHidden = true
                goforwardBtn.isHidden = true
                gobackwardBtn.isHidden = true
            } else {
                setControlsHidden(but: closeBtn)
                let image = UIImage.tintWhiteImageWith(systemName: "play.slash.fill")
                let imageView = UIImageView(image: image)
                addSubview(imageView)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                    imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                    imageView.heightAnchor.constraint(equalToConstant: 50),
                    imageView.widthAnchor.constraint(equalToConstant: 50)
                ])
            }
        }
    }
    /// 视频总时长
    var videoTotalSeconds: Double? {
        didSet {
            guard let videoTotalSeconds else { return }
            rightTimeLabel.text = videoTotalSeconds.toVideoDisplayText()
            leftTimeLabel.text = "00:00"
        }
    }
    /// 视频线播放时长
    var videoCurrentSeconds: Double? {
        didSet {
            guard let videoCurrentSeconds else { return }
            leftTimeLabel.text = videoCurrentSeconds.toVideoDisplayText()
            rightTimeLabel.text = ((videoTotalSeconds ?? 0) - videoCurrentSeconds).toVideoDisplayText()
            progressView.progress = Float(videoCurrentSeconds / videoTotalSeconds!)
        }
    }
    
    // MARK: - 私有属性
    
    /// 持久化监听
    private var disposeBag = Set<AnyCancellable>()
    /// 拖动手势缓存值
    private var panTempPointX = 0.0
    /// 播放速度缓存值
    private var tempSpeed: Float = 1.0
    /// 定时器
    private var timer: Timer!
    /// 按钮消失时间
    private var dismissTime: Int = Int.max
    
    // MARK: - UI 元素
    
    /// 关闭按钮
    lazy var closeBtn: UIButton = {
        generateButton(imageName: "xmark.circle", selector: #selector(PlayerMaskView.closeBtnAction))
    }()
    /// 画中画按钮
    lazy var pipBtn: UIButton = {
        let button = generateButton(imageName: "pip", selector: #selector(PlayerMaskView.enterPiPAction))
        return button
    }()
    /// 锁定屏幕旋转
    lazy var lockScreenBtn: UIButton = {
        let button = generateButton(imageName: "lock.open",
                                    selector: #selector(PlayerMaskView.lockScreenOritention(btn:)))
        button.setImage(UIImage.tintWhiteImageWith(systemName: "lock"), for: .selected)
        return button
    }()
    /// 全屏切换按钮
    lazy var fullScreenBtn: UIButton = {
        let button = generateButton(imageName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left",
                                    selector: #selector(PlayerMaskView.toggleFullScreen))
        return button
    }()
    /// AirPlay 视图按钮
    lazy var routePickerView: AVRoutePickerView = {
        let view = AVRoutePickerView()
        view.delegate = self
        return view
    }()
    /// 中央播放按钮
    lazy var centerBtn: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage.tintWhiteImageWith(systemName: "play.fill"), for: .normal)
        button.setBackgroundImage(UIImage.tintWhiteImageWith(systemName: "pause.fill"), for: .selected)
        button.addTarget(self, action: #selector(PlayerMaskView.centerBtnAction), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    /// 快进按钮
    lazy var goforwardBtn: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage.tintWhiteImageWith(systemName: "goforward.15"), for: .normal)
        button.addTarget(self, action: #selector(PlayerMaskView.goforwardBtnAction), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    /// 回退按钮
    lazy var gobackwardBtn: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage.tintWhiteImageWith(systemName: "gobackward.15"), for: .normal)
        button.addTarget(self, action: #selector(PlayerMaskView.gobackwardBtnAction), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    /// 加载视图
    lazy var loadingView: UIActivityIndicatorView = {
        let loadingView = UIActivityIndicatorView(style: .large)
        loadingView.hidesWhenStopped = true
        loadingView.color = UIColor.white
        loadingView.startAnimating()
        return loadingView
    }()
    /// 左侧时间，已播放时长
    lazy var leftTimeLabel: UILabel = {
        generateTimeLabel()
    }()
    /// 播放进度条
    lazy var progressView: UIProgressView = {
        let view = UIProgressView()
        view.progressTintColor = UIColor.white
        let pan = UIPanGestureRecognizer(target: self, action: #selector(PlayerMaskView.panAction(pan:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
        return view
    }()
    /// 播放进度条的高度约束
    var progressViewHeightConstraint: NSLayoutConstraint!
    /// 右侧时间，总时长
    lazy var rightTimeLabel: UILabel = {
        generateTimeLabel()
    }()
    /// 播放速度按钮
    lazy var speedBtn: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.tintWhiteImageWith(systemName: "speedometer"), for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.menu = getSpeedMenu(currentRate: nil)
        return button
    }()
    
    // MARK: - 生命周期
    
    /// 初始化方法
    override init(frame: CGRect) {
        super.init(frame: frame)
        // 定时器初始化
        timer = Timer(timeInterval: 1, repeats: true, block: { [unowned self] _ in
            let now = Int(Date.now.timeIntervalSince1970.rounded())
            if dismissTime < now && centerBtn.isSelected {
                dismissTime = Int.max
                setControlsHidden()
            }
        })
        RunLoop.current.add(timer, forMode: .common)
        // 判断是否支持画中画功能
        pipBtn.isHidden = !AVPictureInPictureController.isPictureInPictureSupported()
        // 播放或暂停
        let rateCancellable = NotificationCenter.default.publisher(for: AVPlayer.rateDidChangeNotification)
            .sink(receiveValue: { [unowned self] noti in
                guard let player = noti.object as? AVPlayer else { return }
                let rate = player.rate
                centerBtn.isSelected = rate > 0
                tempSpeed = rate
                speedBtn.menu = getSpeedMenu(currentRate: rate)
            })
        rateCancellable.store(in: &disposeBag)
        // 配置子视图
        configSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 视图销毁
    deinit {
        timer.invalidate()
    }
}

// MARK: - 私有方法

extension PlayerMaskView {
    
    /// 设置屏幕按钮消失时间
    private func setNextDismissTime() {
        dismissTime = Int(Date.now.timeIntervalSince1970.rounded() + 5)
    }
    
    /// 控制屏幕按钮显示或隐藏
    /// - Parameter hidden: 是否隐藏
    private func setControlsHidden(_ hidden: Bool = true, but subview: UIView? = nil) {
        for view in subviews where view != subview && view != loadingView {
            if hidden {
                UIView.animate(withDuration: 0.25) {
                    view.alpha = 0
                    self.backgroundColor = UIColor.black.withAlphaComponent(0)
                } completion: { _ in
                    view.isHidden = true
                    view.alpha = 1
                }
            } else {
                if !(view == pipBtn && !AVPictureInPictureController.isPictureInPictureSupported()) && !(view == centerBtn && loadingView.isAnimating) {
                    view.alpha = 0
                    view.isHidden = false
                    UIView.animate(withDuration: 0.25) {
                        view.alpha = 1
                        self.backgroundColor = UIColor.black.withAlphaComponent(0.25)
                    }
                }
            }
        }
    }
    
    /// 获取播放速度菜单
    /// - Returns: 菜单
    private func getSpeedMenu(currentRate: Float?) -> UIMenu {
        var menus: [UIMenuElement] = []
        let speedList: [Float] = [0.5, 1.0, 1.25, 1.5, 1.75]
        for item in speedList {
            let menuAction = UIAction(title: "\(item)") { [unowned self] _ in
                self.tempSpeed = item
                self.delegate?.changeSpeed(item)
                self.speedBtn.menu = getSpeedMenu(currentRate: currentRate)
            }
            menuAction.state = tempSpeed == item ? .on : .off
            menus.append(menuAction)
        }
        var title = ""
        if let currentRate = currentRate {
            title = "当前播放速度为\(currentRate)"
        }
        return UIMenu(title: "\(title)", children: menus)
    }
    
    /// 生成时间显示视图
    /// - Returns: 时间显示视图
    private func generateTimeLabel() -> UILabel {
        let label = UILabel()
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 12)
        label.text = "--:--"
        label.sizeToFit()
        return label
    }
    
    /// 生成居于 systemName image 的按钮
    /// - Parameters:
    ///   - imageName: 图片名称
    ///   - selector: 点击事件
    /// - Returns: 按钮
    private func generateButton(imageName: String, selector: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.tintWhiteImageWith(systemName: imageName),
                        for: .normal)
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }
}


// MARK: - Actions
extension PlayerMaskView {
    /// 关闭事件
    @objc func closeBtnAction() {
        delegate?.closePlayer()
    }
    
    /// 进入画中画
    @objc func enterPiPAction() {
        delegate?.enterPiPMode()
    }
    
    /// 中央按钮事件，播放/暂停
    @objc func centerBtnAction() {
        if centerBtn.isSelected {
            delegate?.pasueAction()
        } else {
            delegate?.playAction()
        }
    }
    
    /// 快进按钮事件
    @objc func goforwardBtnAction() {
        delegate?.goforward()
    }
    
    /// 绘图按钮事件
    @objc func gobackwardBtnAction() {
        delegate?.gobackward()
    }
    
    /// 横竖屏切换事件
    @objc func toggleFullScreen() {
        delegate?.toggleFullScreen()
    }
    
    /// 锁定屏幕旋转事件
    @objc func lockScreenOritention(btn: UIButton) {
        btn.isSelected.toggle()
        delegate?.toggleLockInterface(isLocked: btn.isSelected)
    }
    
    /// 空白区域点击事件
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if centerBtn.isSelected {
            if !closeBtn.isHidden {
                dismissTime = Int.max
                setControlsHidden()
            } else {
                setNextDismissTime()
                setControlsHidden(false)
            }
        }
    }
    
    /// 进度条拖动事件
    @objc func panAction(pan: UIPanGestureRecognizer) {
        if pan.state == .began { // 开始拖拽事件时暂停播放并放大进度条
            guard let delegate else { return }
            delegate.pasueAction()
            panTempPointX = pan.location(in: progressView).x
            self.progressViewHeightConstraint.constant = 10
        } else if pan.state == .ended { // 结束拖拽事件时开始播放并恢复进度条
            panTempPointX = 0
            self.progressViewHeightConstraint.constant = 5
            guard let delegate else { return }
            delegate.seekTo(time: CMTime(seconds: videoCurrentSeconds!, preferredTimescale: 1000))
            delegate.playAction()
        } else if pan.state == .changed { // 拖拽进行时
            let changed = (pan.location(in: progressView).x - panTempPointX) / progressView.bounds.size.width
            progressView.progress += Float(changed)
            videoCurrentSeconds = videoTotalSeconds! * Double(progressView.progress)
            panTempPointX = pan.location(in: progressView).x
        } else { // 取消
            print("cancel")
        }
    }
    
    /// 交互事件重载
    /// 1 进度条可拖动区域扩展
    /// 2 任何的交互事件都重置按钮消失时间
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !closeBtn.isHidden {
            setNextDismissTime()
        }
        if point.y < progressView.frame.origin.y + progressView.frame.height + 15
            && point.y > progressView.frame.origin.y - 15 {
            return progressView
        }
        return super.hitTest(point, with: event)
    }
}

// MARK: - Delgates

extension PlayerMaskView: AVRoutePickerViewDelegate {}

extension PlayerMaskView: UIGestureRecognizerDelegate {
    /// 拖动事件是否开始取决于视频是否准备好
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.view == progressView {
            return videoIsReady == 1
        }
        return true
    }
}
