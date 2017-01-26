//
//  PanController.swift
//  PanController
//

import UIKit

protocol PanControllerDelegate {
    // Scrolling.
    func panController(panController: PanController, didStartPanningFromIndex fromIndex: Int)
    func panController(panController: PanController, didChangePanningFromIndex fromIndex: Int, toIndex: Int, progress: CGFloat)
    func panController(panController: PanController, didStopPanningFromIndex fromIndex: Int, toIndex: Int)
    // Paging.
    func panController(panController: PanController, didPagingFromIndex fromIndex: Int, toIndex: Int)
}

protocol PanControllerChildren {
    func viewWillEnter(withPanController panController: PanController, from: PanController.Direction)
    func viewWillOut(withPanController panController: PanController, to: PanController.Direction)
    func viewDidEnter(withPanController panController: PanController, from: PanController.Direction)
    func viewDidOut(withPanController panController: PanController, to: PanController.Direction)
}

extension PanControllerChildren {
    func viewWillEnter(withPanController panController: PanController, from: PanController.Direction) {}
    func viewWillOut(withPanController panController: PanController, to: PanController.Direction) {}
    func viewDidEnter(withPanController panController: PanController, from: PanController.Direction) {}
    func viewDidOut(withPanController panController: PanController, to: PanController.Direction) {}
}

protocol PanControllerTransformer {
    func panController(_ panController: PanController, views: [UIView], panningFromIndex fromIndex: Int, toIndex: Int, progress: CGFloat)
    func panControllerWillRemoveTransformer(_ panController: PanController, views: [UIView]) // transformerが外されるときに呼ばれる. 後始末しましょう.
}
extension PanControllerTransformer {
    func panControllerWillRemoveTransformer(_ panController: PanController, views: [UIView]) {}
}


//
// 横スワイプで複数の ViewController をページングする.
//
class PanController: UIViewController {

    // note:
    // UIPageViewControllerだとscrollViewの挙動を制御できず、インデックス移動の進捗などを扱い辛いため新規に作成したもの.

    enum Direction { // パン操作の方向.
        case previous
        case center
        case next
        case none
    }

    enum LoopMode { // ループ形式.
        case none   // ループしない.（両端でバウンス）
        case loop   // ループする.
        case bounded    // 両端で抵抗のあるループをする.
    }

    enum ViewStatus {
        case out
        case previous
        case previousIn
        case center
        case nextIn
        case next
    }

    enum ScrollDirection {
        case horizontal
        case vartical
    }

    var scrollView: UIScrollView!
    var containers: [UIView]!

    // ページング・スクロールの状況を受け取るオブジェクト.
    var panDelegate: PanControllerDelegate?

    // ページング対象のViewControllerオブジェクトの配列.
//    var viewControllers: [UIViewController] = [] {
//        didSet {
//            if let _ = self.scrollView {
//                updateContainer()
//            }
//            childStatus = [ViewStatus](repeating: .out, count: count)
//        }
//    }

    var pages: [AnyObject] = [] {
        didSet {
            for (i, obj) in pages.enumerated().reversed() {
                if let _: UIView = obj as? UIView { continue }
                if let _: UIViewController = obj as? UIViewController { continue }
                print("PanController.pages.didSet> WARNING! invalid class object(\(i)). removed.")
                pages.remove(at: i)
            }
            if let _ = self.scrollView {
                updateContainer()
            }
            childStatus = [ViewStatus](repeating: .out, count: count)
        }
    }
    func pageView(at index: Int) -> UIView? {
        if let v: UIView = pages[index] as? UIView { return v }
        if let vc: UIViewController = pages[index] as? UIViewController { return vc.view }
        return nil
    }

    // 現在のパン操作の方向.
    var panningDirection: Direction {
        if scrollValue < scrollWidth { return .previous }
        else if scrollValue > scrollWidth { return .next }
        else { return .center }
    }
    // (loopMode = .bounded のとき)両端で引っ張ってループする progress の閾値.
    var pullingProgressThreshold: CGFloat = 0.28
    // ループ形式.
    var loopMode: LoopMode = .loop {
        didSet {
            if let _ = self.scrollView {
                self.updateContainer()
            }
        }
    }
    // ページングする ViewController の数.
    var count: Int {
        return pages.count
    }
    // 現在見ている ViewController のインデックス.
    var index: Int {
        return currentIndex
    }
    // 完全に外側になった ViewController の view を hidden にするか否か.
    var hideOutsideViews: Bool = false {
        // loopMode でループする設定のとき、
        // 左右に同じ ViewControllerの view が見える状況になっても実際には片方しか表示されないので注意.
        didSet {
            if let scrollView = self.scrollView {
                panScrollViewDidScroll(scrollView)
            }
        }
    }
    // スクロール量に応じて各コンテナを変形させる処理を実装したオブジェクト.
    var transformer: PanControllerTransformer? {
        didSet {
            if let scrollView = self.scrollView {
                oldValue?.panControllerWillRemoveTransformer(self, views: containers)
                panScrollViewDidScroll(scrollView)
            }
        }
    }
    // スクロール方向.
    var scrollDirection: ScrollDirection = .horizontal {
        didSet {
            if scrollView?.subviews.count ?? 0 > 0 {
                containIndices = [0, 0, 0]
                buildViews()
            }
        }
    }
    
    // 現時点のページ番号.
    private var currentIndex: Int = 0
    // 移動先のページ番号.
    private var rightIndex: Int = 0
    // 移動開始した時点のページ番号.
    private var recentIndex: Int = 0
    // ページジャンプ中を示すフラグ.
    private var isJumping: Bool = false
    // 各ViewControllerの状態.
    private var childStatus: [ViewStatus] = []
    // 各コンテナに格納されているViewControllerのインデックス. 空は -1.
    private var containIndices: [Int] = [-1, -1, -1]
    // スクロール関連の変数.
    // ！！ 方向によってアクセス先を切り替えているので、ここに挙げたものは直接操作しないこと　！！
    private var scrollValue: CGFloat {
        set (newValue) {
            switch scrollDirection {
            case .horizontal:
                scrollView.contentOffset = CGPoint(x: newValue, y: 0)
            case .vartical:
                scrollView.contentOffset = CGPoint(x: 0, y: newValue)
            }
        }
        get {
            switch scrollDirection {
            case .horizontal:   return scrollView?.contentOffset.x ?? 0
            case .vartical:     return scrollView?.contentOffset.y ?? 0
            }
        }
    }
    private var scrollWidth: CGFloat {
        switch scrollDirection {
        case .horizontal:   return scrollView.bounds.size.width
        case .vartical:     return scrollView.bounds.size.height
        }
    }
    private var prevScrollInset: CGFloat {
        set (newValue) {
            switch scrollDirection {
            case .horizontal: scrollView.contentInset.left = newValue
            case .vartical: scrollView.contentInset.top = newValue
            }
        }
        get {
            switch scrollDirection {
            case .horizontal: return scrollView.contentInset.left
            case .vartical: return scrollView.contentInset.top
            }
        }
    }
    private var nextScrollInset: CGFloat {
        set (newValue) {
            switch scrollDirection {
            case .horizontal: scrollView.contentInset.right = newValue
            case .vartical: scrollView.contentInset.bottom = newValue
            }
        }
        get {
            switch scrollDirection {
            case .horizontal: return scrollView.contentInset.right
            case .vartical: return scrollView.contentInset.bottom
            }
        }
    }
    private func position(ofContainer containerView: UIView) -> CGFloat {
        switch scrollDirection {
        case .horizontal: return containerView.frame.origin.x
        case .vartical: return containerView.frame.origin.y
        }
    }
    private func contentOffset(forIndex index: Int) -> CGPoint {
        switch scrollDirection {
        case .horizontal: return CGPoint(x: index == 0 ? 0 : scrollWidth * 2, y: 0)
        case .vartical: return CGPoint(x: 0, y: index == 0 ? 0 : scrollWidth * 2)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containers = [UIView(), UIView(), UIView()]

        buildViews()
        scrollView.delegate = self
    }

    //
    // スクロールとコンテナの view 生成.
    //
    func buildViews() {

        view.clipsToBounds = false
        scrollView?.removeFromSuperview()
        scrollView = UIScrollView()
        scrollView.clipsToBounds = false
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        view.addSubview(scrollView)
        containers.forEach {
            $0.removeFromSuperview()
            scrollView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        var dir1: String!
        var dir2: String!
        switch scrollDirection {
        case .horizontal:
            dir1 = "H:"
            dir2 = "V:"
        case .vartical:
            dir1 = "V:"
            dir2 = "H:"
        }
        addFillingParentConstraints(toView: scrollView)
        let views = ["scr": scrollView, "v0": containers[0], "v1": containers[1], "v2": containers[2]]
        scrollView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: dir1 + "|-0-[v0(==scr)]-0-[v1(==scr)]-0-[v2(==scr)]-0-|", metrics: nil, views: views))
        scrollView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: dir2 + "|-0-[v0(==scr)]-0-|", metrics: nil, views: views))
        scrollView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: dir2 + "|-0-[v1(==scr)]-0-|", metrics: nil, views: views))
        scrollView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: dir2 + "|-0-[v2(==scr)]-0-|", metrics: nil, views: views))
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        scrollValue = scrollWidth
        panScrollViewDidScroll(scrollView, ignoreDelegate: true)

        scrollView.delegate = self

    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.layoutIfNeeded()
        if !isJumping {
            updateContainer()
            scrollValue = scrollWidth
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkSubviewsStatus(withCall: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    //
    // 子 ViewController になる手続き.
    //
    func becomeChildViewController(ofViewController parentVC: UIViewController, inView containerView: UIView) {
        let _ = view
        parentVC.addChildViewController(self)
        containerView.addSubview(view)
        addFillingParentConstraints(toView: view)
        didMove(toParentViewController: parentVC)
    }

    //
    // ページ ジャンプ.
    //
    func jumpTo(index: Int) {
        if index < 0 || index >= count {
            print("PanController.jumpTo(_:)> WARNING! invalid index value(\(index)). ignored.")
            return
        }
        recentIndex = currentIndex
        currentIndex = index
        panDelegate?.panController(panController: self, didPagingFromIndex: recentIndex, toIndex: currentIndex)
        updateContainer()
    }
    func jumpTo(index: Int, animated: Bool) {
        if index < 0 || index >= count {
            print("PanController.jumpTo(_:,_:)> WARNING! invalid index value(\(index)). ignored.")
            return
        }
        if !animated {
            jumpTo(index: index)
            return
        }
        var i: Int = 0 // 次の ViewController を格納するコンテナのインデックス.
        switch loopMode {
        case .none, .bounded:
            i = index < currentIndex ? 0 : 2
        case .loop:
            if abs(currentIndex - index) <= count / 2 {
                i = index < currentIndex ? 0 : 2
            }
            else {
                i = index < currentIndex ? 2 : 0
            }
        }
        if let pageView: UIView = pageView(at: index) {
            containers[i].subviews.forEach { $0.removeFromSuperview() }
            containers[i].addSubview(pageView)
            addFillingParentConstraints(toView: pageView)
            containers[i].setNeedsLayout()
            containers[i].layoutIfNeeded()
        }
        rightIndex = index
        isJumping = true
        panScrollViewWillBeginScrolling(scrollView)
        checkSubviewsStatus()

        scrollView.setContentOffset(contentOffset(forIndex: i), animated: true)

    }

    //
    // コンテナの中身更新.
    //
    fileprivate func updateContainer() {

        if count == 0 { return }
        
        if (currentIndex < 0 || currentIndex >= count) {
            // 異常. インデックスがページ範囲の外にある. → 0 に設定して続行する.
            print("PanController.updateContainer()> WARNING! invalid currentIndex value(\(currentIndex)). currentIndex is set to 0.")
            currentIndex = 0
        }
        
        var newIndices = [-1, -1, -1]
        if count > 2 {
            for i in 0..<3 {
                var p: Int = currentIndex + i - 1
                if p < 0 { p = count - 1}
                if p >= count { p = 0 }
                newIndices[i] = p
            }
            switch loopMode {
            case .loop:
                containers[0].transform = CGAffineTransform.identity
                containers[2].transform = CGAffineTransform.identity
                prevScrollInset = 0
                nextScrollInset = 0
            case .none:
                containers[0].transform = CGAffineTransform.identity
                containers[2].transform = CGAffineTransform.identity
                prevScrollInset = currentIndex == 0 ? -scrollWidth : 0
                nextScrollInset = currentIndex == count - 1 ? -scrollWidth : 0
            case .bounded:
                containers[0].transform = currentIndex == 0 ? CGAffineTransform(translationX: -scrollWidth, y: 0) : CGAffineTransform.identity
                containers[2].transform = (currentIndex == count - 1) ? CGAffineTransform(translationX: scrollWidth, y: 0) : CGAffineTransform.identity
                prevScrollInset = currentIndex == 0 ? -scrollWidth : 0
                nextScrollInset = currentIndex == count - 1 ? -scrollWidth : 0
            }
        }
        else if count > 1 {
            // ２ページあるとき.
            switch loopMode {
            case .loop:
                containers[0].transform = CGAffineTransform.identity
                containers[2].transform = CGAffineTransform.identity
                prevScrollInset = 0
                nextScrollInset = 0
            case .none:
                containers[0].transform = CGAffineTransform.identity
                containers[2].transform = CGAffineTransform.identity
                prevScrollInset = currentIndex == 0 ? -scrollWidth : 0
                nextScrollInset = currentIndex == count - 1 ? -scrollWidth : 0
            case .bounded:
                containers[0].transform = currentIndex == 0 ? CGAffineTransform(translationX: -scrollWidth, y: 0) : CGAffineTransform.identity
                containers[2].transform = (currentIndex == count - 1) ? CGAffineTransform(translationX: scrollWidth, y: 0) : CGAffineTransform.identity
                prevScrollInset = currentIndex == 0 ? -scrollWidth : 0
                nextScrollInset = currentIndex == count - 1 ? -scrollWidth : 0
            }
            // コンテナ 0 と 2 は 後で設定する.
            newIndices[1] = currentIndex
        }
        else {
            // １ページしかないとき.
            containers[0].transform = CGAffineTransform.identity
            containers[2].transform = CGAffineTransform.identity
            prevScrollInset = -scrollWidth
            nextScrollInset = -scrollWidth
            newIndices[1] = currentIndex
        }
        for (i, newIndex) in newIndices.enumerated() {
            if newIndex >= 0 && newIndex != containIndices[i] {
                let container = containers[i]
                if let contentView: UIView = pageView(at: newIndex) {
                    container.subviews.forEach{ $0.removeFromSuperview() }
                    container.addSubview(contentView)
                    addFillingParentConstraints(toView: contentView)
                    containIndices[i] = newIndex
                }
            }
        }
    }
    
    //
    // (loopMode = .bounded のとき)両端で引っ張った.
    //
    private func pullAtBounds() {
        switch panningDirection {
        case .next:
            UIView.animate(withDuration: 0.2,
                           delay: 0,
                           options: [.beginFromCurrentState, .allowUserInteraction] ,
                           animations: {_ in
                            self.containers[2].transform = CGAffineTransform.identity },
                           completion: nil)
            self.nextScrollInset =  0
        case .previous:
            UIView.animate(withDuration: 0.2,
                           delay: 0,
                           options: [.beginFromCurrentState, .allowUserInteraction] ,
                           animations: {_ in
                            self.containers[0].transform = CGAffineTransform.identity },
                           completion: nil)
            self.prevScrollInset =  0
        default: break
        }
    }

    //
    // 各コンテナの現在の表示位置を確認して、必要に応じて 出現・消滅イベントを投げる.
    //
    private func checkSubviewsStatus(withCall: Bool = true) {
        for (i, pageObj) in pages.enumerated() {
            var newStat: ViewStatus = .out
            if let cvc: PanControllerChildren = pageObj as? PanControllerChildren {
                let view: UIView? = pageView(at: i)
                // 状態マトリックス更新.
                if let spView = view?.superview {
                    let x = position(ofContainer: spView) - scrollValue
                    if x < -scrollWidth { newStat = .out }
                    else if x == -scrollWidth { newStat = .previous }
                    else if x < 0 { newStat = .previousIn }
                    else if x == 0 { newStat = .center }
                    else if x < scrollWidth { newStat = .nextIn }
                    else if x == scrollWidth { newStat = .next }
                    else { newStat = .out }
                }
                else {
                    newStat = .out
                }
                if withCall {
                    switch childStatus[i] {
                    case .center:
                        switch newStat {
                        case .out, .previous, .next:
                            cvc.viewWillOut(withPanController: self, to: .none)
                            cvc.viewDidOut(withPanController: self, to: .none)
                        case .previousIn:
                            cvc.viewWillOut(withPanController: self, to: .previous)
                        case .center:
                            break
                        case .nextIn:
                            cvc.viewWillOut(withPanController: self, to: .next)
                        }
                    case .previousIn:
                        switch newStat {
                        case .out, .previous, .next:
                            cvc.viewDidOut(withPanController: self, to: .previous)
                        case .previousIn:
                            break
                        case .center:
                            cvc.viewDidEnter(withPanController: self, from: .previous)
                        case .nextIn:
                            break
                        }
                    case .nextIn:
                        switch newStat {
                        case .out, .previous, .next:
                            cvc.viewDidOut(withPanController: self, to: .next)
                        case .previousIn:
                            break
                        case .center:
                            cvc.viewDidEnter(withPanController: self, from: .next)
                        case .nextIn:
                            break
                        }
                    case .previous:
                        switch newStat {
                        case .out, .previous, .next:
                            break
                        case .previousIn:
                            cvc.viewWillEnter(withPanController: self, from: .previous)
                        case .center:
                            cvc.viewWillEnter(withPanController: self, from: .none)
                            cvc.viewDidEnter(withPanController: self, from: .none)
                        case .nextIn:
                            cvc.viewWillEnter(withPanController: self, from: .next)
                        }
                    case .next:
                        switch newStat {
                        case .out, .previous, .next:
                            break
                        case .previousIn:
                            cvc.viewWillEnter(withPanController: self, from: .previous)
                        case .center:
                            cvc.viewWillEnter(withPanController: self, from: .none)
                            cvc.viewDidEnter(withPanController: self, from: .none)
                        case .nextIn:
                            cvc.viewWillEnter(withPanController: self, from: .next)
                        }
                    case  .out:
                        switch newStat {
                        case .out, .previous, .next:
                            break
                        case .previousIn:
                            cvc.viewWillEnter(withPanController: self, from: .previous)
                        case .center:
                            cvc.viewWillEnter(withPanController: self, from: .none)
                            cvc.viewDidEnter(withPanController: self, from: .none)
                        case .nextIn:
                            cvc.viewWillEnter(withPanController: self, from: .next)
                        }
                    }
                }
                childStatus[i] = newStat
            }
        }
    }
    
    //
    // スクロールイベントハンドラ.
    //
    fileprivate func panScrollViewDidScroll(_ scrollView: UIScrollView, ignoreDelegate: Bool = false) {
        
        scrollView.delegate = nil

        containers.forEach { $0.layer.transform = CATransform3DIdentity }
        
        // 移動.
        //        var rightIndex: Int = currentIndex
        let progress: CGFloat = abs(scrollValue / scrollWidth - 1)
        var willBeyondBound = false
        var containerHasUpdated: Bool = false
        
        if !isJumping {
            if scrollValue < scrollWidth {
                recentIndex = currentIndex
                rightIndex = currentIndex - 1
                if rightIndex < 0 {
                    rightIndex = loopMode == .none ? 0 : count - 1
                    willBeyondBound = true
                }
            }
            else if scrollValue > scrollWidth {
                recentIndex = currentIndex
                rightIndex = currentIndex + 1
                if rightIndex >= count {
                    rightIndex = loopMode == .none ? count - 1 : 0
                    willBeyondBound = true
                }
            }
        }
        transformer?.panController(self, views: containers, panningFromIndex: currentIndex, toIndex: rightIndex, progress: progress)

        // 境界.
        if count == 2 && currentIndex != rightIndex {
            // 2 ページしかない状態でループする場合、左右両方のコンテナが同じ ViewController を使うことになるため特別.
            let rightContainer: UIView = containers[scrollValue < scrollWidth ? 0 : 2]
            if rightContainer.subviews.count == 0 {
                if let nextView: UIView = pageView(at: rightIndex) {
                    rightContainer.addSubview(nextView)
                    addFillingParentConstraints(toView: nextView)
                }
            }
        }
        if (count > 1) {
            if scrollValue <= 0 {
                currentIndex = rightIndex
                scrollValue += scrollWidth
                updateContainer()
                containerHasUpdated = true
            }
            else if scrollValue >= scrollWidth * 2 {
                currentIndex = rightIndex
                scrollValue -= scrollWidth
                updateContainer()
                containerHasUpdated = true
            }
            else {
                if loopMode == .bounded && willBeyondBound {
                    if progress >= pullingProgressThreshold && scrollView.isTracking {
                        pullAtBounds()
                    }
                }
            }
        }
        
        if !ignoreDelegate {
            panDelegate?.panController(panController: self, didChangePanningFromIndex: recentIndex, toIndex: rightIndex, progress: progress)
        }

        checkSubviewsStatus()

        scrollView.delegate = self
        
        if containerHasUpdated {
            transformer?.panController(self, views: containers, panningFromIndex: currentIndex, toIndex: 0, progress: 0)
        }
        else {
//            transformer?.panController(self, views: containers, panningFromIndex: currentIndex, toIndex: currentIndex, progress: 0)
        }

        if hideOutsideViews {
            switch panningDirection {
            case .center:
                containers[0].isHidden = true
                containers[2].isHidden = true
            case .previous:
                containers[0].isHidden = loopMode == .none && currentIndex == 0
                containers[2].isHidden = true
            case  .next:
                containers[0].isHidden = true
                containers[2].isHidden = loopMode == .none && currentIndex == count - 1
            case .none:
                containers[0].isHidden = true
                containers[2].isHidden = true
            }
        } else {
            // 非ループモードで範囲外は必ず消す.
            switch panningDirection {
            case .previous:
                containers[0].isHidden = loopMode == .none && currentIndex == 0
            case  .next:
                containers[2].isHidden = loopMode == .none && currentIndex == count - 1
            default: break
            }
        }
    }
    
    fileprivate func panScrollViewWillBeginScrolling(_ scrollView: UIScrollView) {
        if scrollView.isTracking {
            isJumping = false
        }
        recentIndex = currentIndex
        panDelegate?.panController(panController: self, didStartPanningFromIndex: recentIndex)
    }

    fileprivate func panScrollViewDidEndScrolling(_ scrollView: UIScrollView) {
        isJumping = false
        panDelegate?.panController(panController: self, didStopPanningFromIndex: recentIndex, toIndex: currentIndex)
        panDelegate?.panController(panController: self, didPagingFromIndex: recentIndex, toIndex: currentIndex)
        checkSubviewsStatus()
        updateContainer()
    }

    //
    // superview を覆う constraint を（親に）設定する.
    //
    private func addFillingParentConstraints(toView view: UIView) {
        guard let sview = view.superview else { return }
        let views = ["innerView":view]
        sview.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[innerView]-0-|", metrics: nil, views: views))
        sview.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[innerView]-0-|", metrics: nil, views: views))
        view.translatesAutoresizingMaskIntoConstraints = false
    }

}

extension PanController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.panScrollViewDidScroll(scrollView)
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.panScrollViewWillBeginScrolling(scrollView)
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { self.panScrollViewDidEndScrolling(scrollView) }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.panScrollViewDidEndScrolling(scrollView)
    }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.panScrollViewDidEndScrolling(scrollView)
    }
}

