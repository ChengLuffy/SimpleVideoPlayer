import UIKit
import AVKit
import Combine

public protocol SimpleVideoPlayerDelegate: AnyObject {
    func playerViewController(_ playerViewController: SimpleVideoPlayer,
                              restoreUserInterfaceForPIPStopWithCompletionHandler
                              completionHandler: @escaping (Bool) -> Void
    )
}

/// 持久化
private var activePlayer = Set<SimpleVideoPlayer>()
public class SimpleVideoPlayer: UIViewController {
    
    // MARK: - 公开属性
    
    /// 视频总时长订阅
    public private(set) var totalTimeSubject: CurrentValueSubject<CMTime?, Never> = CurrentValueSubject(nil)
    /// 视频现在播放时长
    public private(set) var currentTimeSubject: CurrentValueSubject<CMTime?, Never> = CurrentValueSubject(nil)
    /// 用于画中画恢复的代理
    public weak var delegate: SimpleVideoPlayerDelegate?
    
    // MARK: - 构建方法
    
    /// 私有化 init 方法
    private init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    /// 用视频播放链接构建
    /// - Parameter urlStr: 视频播放链接
    public convenience init(urlStr: String) {
        self.init()
        self.urlStr = urlStr
    }
    
    /// 用视频文件地址构建
    /// - Parameter filePath: 视频文件地址
    public convenience init(filePath: String) {
        self.init()
        self.filePath = filePath
    }
    
    /// 用 AVPlayerItem 构建
    /// - Parameter playItem: AVPlayerItem
    public convenience init(playItem: AVPlayerItem) {
        self.init()
        self.playerItem = playItem
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 私有属性
    
    /// 交互动画驱动
    private var percentTranstion: UIPercentDrivenInteractiveTransition?
    /// 视频监听上下文
    private var playerItemContext = 0
    /// 锁定旋转时的屏幕方向
    private var lockInterfaceOrientation: UIInterfaceOrientationMask?
    /// 播放监听持久
    private var timeObserverToken: Any?
    /// 播放链接
    private var urlStr: String? { didSet { didSetUrlStr() }}
    /// 播放文件地址
    private var filePath: String? { didSet { didSetFilePath() }}
    /// 已经构建好的视频播放项
    private var playerItem: AVPlayerItem? { didSet { didSetPlayerItem() }}
    /// 视频播放器
    private var _player: AVPlayer?
    private var player: AVPlayer? {
        get { return _player }
        set {
            _player = newValue
            if let player, let timeObserverToken {
                player.removeTimeObserver(timeObserverToken)
            }
            playerView.player = newValue
            guard let player = newValue else { return }
            let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval,
                                                               queue: DispatchQueue.main) { [unowned self] _ in
                dealProgress()
            }
        }
    }
    /// 视频播放视图
    private lazy var playerView: PlayerView = { PlayerView() }()
    /// 画中画控制器
    private var pipController: AVPictureInPictureController?
    /// 播放控制层
    private lazy var maskView: PlayerMaskView = {
        let view = PlayerMaskView()
        view.delegate = self
        return view
    }()
    
    // MARK: - 生命周期
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        // 构建方法并不会触发 setter
        if urlStr != nil {
            didSetUrlStr()
        } else if filePath != nil {
            didSetFilePath()
        } else if playerItem != nil {
            didSetPlayerItem()
        }
        configUI()
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: playerView.playerLayer)
            pipController?.delegate = self
        }
        // 下拉返回的手势
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panAction(pan:)))
        view.addGestureRecognizer(pan)
        self.transitioningDelegate = self
    }
    
    deinit {
        print("deinit")
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges))
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferEmpty))
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp))
        guard let player, let timeObserverToken else { return }
        player.removeTimeObserver(timeObserverToken)
    }
    
    // MARK: - 继承
    
    /// 屏幕方向
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return lockInterfaceOrientation ?? .allButUpsideDown
    }
    
    // swiftlint:disable block_based_kvo
    /// 监听回调
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                      change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        // swiftlint:enable block_based_kvo
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if keyPath == #keyPath(AVPlayerItem.status) {
            dealStatusObserve(change: change)
        } else if keyPath == #keyPath(AVPlayerItem.loadedTimeRanges) {
        } else if keyPath == #keyPath(AVPlayerItem.isPlaybackBufferEmpty) {
            maskView.videoIsReady = 0
        } else if keyPath == #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp) {
            maskView.videoIsReady = 1
        }
    }
}

// MARK: - 方法

extension SimpleVideoPlayer {
    /// 配置子视图
    func configUI() {
        view.backgroundColor = UIColor.black
        
        view.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(maskView)
        maskView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            playerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playerView.widthAnchor.constraint(equalTo: view.widthAnchor),
            playerView.heightAnchor.constraint(equalTo: view.heightAnchor),
            maskView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            maskView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            maskView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor),
            maskView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor)
        ])
    }
    
    /// 处理视频播放进度
    func dealProgress() {
        guard let playerItem else { return }
        guard playerItem.status == .readyToPlay else { return }
        currentTimeSubject.send(playerItem.currentTime())
        maskView.videoCurrentSeconds = playerItem.currentTime().seconds
    }
    
    /// 将视频播放链接处理为 AVPlayerItem
    func didSetUrlStr() {
        guard let urlStr else { return }
        guard let url = URL(string: urlStr) else { return }
        let item = AVPlayerItem(url: url)
        playerItem = item
    }
    
    /// 将视频文件地址处理为 AVPlayerItem
    func didSetFilePath() {
        guard let filePath else { return }
        let url: URL
        url = URL(filePath: filePath)
        let item = AVPlayerItem(url: url)
        playerItem = item
    }
    
    /// 配置 AVPlayerItem
    func didSetPlayerItem() {
        guard let playerItem else {
            player?.replaceCurrentItem(with: nil)
            return
        }
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status),
                               options: [.new],
                               context: &playerItemContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges),
                               options: [.new],
                               context: &playerItemContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferEmpty),
                               options: [.new],
                               context: &playerItemContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp),
                               options: [.new],
                               context: &playerItemContext)
        if playerView.player == nil {
            let player = AVPlayer(playerItem: playerItem)
            self.player = player
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
    }
    
    /// 下拉返回的手势处理
    @objc func panAction(pan: UIPanGestureRecognizer) {
        let distance = pan.translation(in: self.view).y / (view.bounds.height / 3)
        if pan.state == .began {
            self.percentTranstion = UIPercentDrivenInteractiveTransition()
            // 触发交互式动画
            self.dismiss(animated: true, completion: nil)
        } else if pan.state == .changed {
            self.percentTranstion?.update(distance)
        } else if pan.state == .ended || pan.state == .cancelled {
            if distance > 0.5 {
                self.percentTranstion?.finish()
            } else {
                self.percentTranstion?.cancel()
            }
            self.percentTranstion = nil
        }
    }
    
    /// 视频播放项目状态监听处理
    func dealStatusObserve(change: [NSKeyValueChangeKey: Any]?) {
        let status: AVPlayerItem.Status
        if let statusNumber = change?[.newKey] as? NSNumber {
            status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
        } else {
            status = .unknown
        }
        switch status {
        case .readyToPlay:
            print("status: readyToPlay")
            maskView.videoIsReady = 1
            totalTimeSubject.send(playerItem?.duration ?? nil)
            guard let playerItem else { return }
            let seconds = playerItem.duration.seconds
            maskView.videoTotalSeconds = seconds
        case .failed:
            print("status: failed")
            maskView.videoIsReady = -1
        case .unknown:
            print("status: unknown")
        default: print("status: default")
        }
    }
}

// MARK: - 代理

extension SimpleVideoPlayer: AVPictureInPictureControllerDelegate {
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                           failedToStartPictureInPictureWithError error: Error) {
        print(error)
        activePlayer.remove(self)
    }
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController:
                                                                    AVPictureInPictureController) {
        activePlayer.insert(self)
    }
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController:
                                                                   AVPictureInPictureController) {
        dismiss(animated: true)
    }
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController:
                                                                  AVPictureInPictureController) {
        activePlayer.remove(self)
    }
    public func pictureInPictureController(_ pictureInPictureController:
                                           AVPictureInPictureController,
                                           restoreUserInterfaceForPictureInPictureStopWithCompletionHandler
                                           completionHandler: @escaping (Bool) -> Void) {
        delegate?.playerViewController(self, restoreUserInterfaceForPIPStopWithCompletionHandler: completionHandler)
    }
}

extension SimpleVideoPlayer: PlayerMaskViewDelegate {
    func pasueAction() {
        player?.pause()
    }
    
    func playAction() {
        player?.play()
    }
    
    func seekTo(time: CMTime) {
        player?.seek(to: time)
    }
    
    func closePlayer() {
        dismiss(animated: true)
    }
    
    func enterPiPMode() {
        pipController?.startPictureInPicture()
    }
    
    func toggleFullScreen() {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        if windowScene?.interfaceOrientation != .portrait {
            windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        } else {
            windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeLeft))
        }
    }
    
    func toggleLockInterface(isLocked: Bool) {
        if isLocked {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            if let interface = windowScene?.interfaceOrientation {
                switch interface {
                case .unknown, .portrait, .portraitUpsideDown:
                    lockInterfaceOrientation = .portrait
                case .landscapeLeft:
                    lockInterfaceOrientation = .landscapeLeft
                case .landscapeRight:
                    lockInterfaceOrientation = .landscapeRight
                @unknown default:
                    lockInterfaceOrientation = .portrait
                }
            } else {
                lockInterfaceOrientation = .portrait
            }
        } else {
            lockInterfaceOrientation = nil
        }
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }
    
    func changeSpeed(_ speed: Float) {
        player?.rate = speed
    }
    
    func goforward() {
        player?.seek(to: CMTime(seconds: (playerItem?.currentTime().seconds ?? 0) + 15, preferredTimescale: 1000))
    }
    
    func gobackward() {
        player?.seek(to: CMTime(seconds: (playerItem?.currentTime().seconds ?? 15) - 15, preferredTimescale: 1000))
    }
}

extension SimpleVideoPlayer: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController,
                                    presenting: UIViewController,
                                    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissTransition().reloadWithPresent(isPresent: true)
    }
    
    public func animationController(forDismissed dismissed: UIViewController) ->
        UIViewControllerAnimatedTransitioning? {
        return DismissTransition().reloadWithPresent(isPresent: false)
    }
    
    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) ->
        UIViewControllerInteractiveTransitioning? {
        return percentTranstion
    }
}
