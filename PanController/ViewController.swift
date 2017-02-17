//
//  ViewController.swift
//  PanController
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    let panController = PanController()


    override func viewDidLoad() {
        super.viewDidLoad()

        var vcs: [AnyObject] = []
        for i: Int in 0..<8 {
            if i % 2 == 0 {
                // 偶数ページには UILabel をそのまま設定.
                let label = UILabel()
                label.backgroundColor =  UIColor(hue: CGFloat(i) / 8, saturation: 1, brightness: 1, alpha: 1)
                label.text = "Label \(i)"
                vcs.append(label)
            }
            else {
                // 奇数ページには DummyViewController を設定.
                let vc = DummyViewController(i)
                vc.view.backgroundColor =  UIColor(hue: CGFloat(i) / 8, saturation: 0.5, brightness: 1, alpha: 1)
                vc.label.textColor = UIColor(hue: CGFloat(i) / 8, saturation: 0.9, brightness: 1, alpha: 1)
                vcs.append(vc)
            }
        }
        panController.loopMode = .none
        panController.scrollDirection = .horizontal
        panController.panDelegate = self
        panController.hideOutsideViews = false        
        panController.transformer = nil
        containerView.clipsToBounds = true

        // UIViewControlller オブジェクトの配列を渡します.
        panController.pages = vcs

        // 誰かの子ViewControllerになります.
        panController.becomeChildViewController(ofViewController: self, inView: containerView)

    }

    @IBAction func onChangedSegmentedControl(_ sender: UISegmentedControl) {

        // ページスキップ.
        panController.jumpTo(index: sender.selectedSegmentIndex, animated: true)

    }

    @IBAction func onChangedLoopMode(_ sender: UISegmentedControl) {

        // ループモード切り替え.
        panController.loopMode = [PanController.LoopMode.none,
                                  PanController.LoopMode.loop,
                                  PanController.LoopMode.bounded][sender.selectedSegmentIndex]
    }
    @IBAction func onChangedDirection(_ sender: UISegmentedControl) {

        // スクロール方向切り替え. タテ（下）または ヨコ（右）.
        panController.scrollDirection = sender.selectedSegmentIndex == 0 ? .horizontal : .vartical

    }
    @IBAction func onChangedTransition(_ sender: UISegmentedControl) {
        
        // スクロールの演出切り替え.
        // サンプルのクラスは このファイルの下のほうで定義しています.
        switch sender.selectedSegmentIndex {
        case 0:
            panController.transformer = nil
            containerView.clipsToBounds = true
        case 1:
            panController.transformer = ParallaxTransitionTransform()
            containerView.clipsToBounds = true
        case 2:
            panController.transformer = CardStackTransitionTransform()
            containerView.clipsToBounds = true
        case 3:
            panController.transformer = FlipTransitionTransform(1)
            containerView.clipsToBounds = false
        default:
            panController.transformer = RotateTransitionTransform()
            containerView.clipsToBounds = false
            
        }
    }


}

//
// ページ移動イベントのハンドラ.
//
extension ViewController: PanControllerDelegate {

    func panController(panController: PanController, didStartPanningFromIndex fromIndex: Int) {
//        print("panControllerDidPan(fromIndex: \(fromIndex))")
    }
    func panController(panController: PanController, didChangePanningFromIndex fromIndex: Int, toIndex: Int, progress: CGFloat) {
//        print("panControllerDidPan(fromIndex: \(fromIndex), toIndex: \(toIndex), progress: \(progress))")
//        self.segmentedControl.selectedSegmentIndex = fromIndex
    }
    func panController(panController: PanController, didStopPanningFromIndex fromIndex: Int, toIndex: Int) {
//        print("panControllerDidStopPanning(fromIndex: \(fromIndex), toIndex: \(toIndex)) ")
    }
    func panController(panController: PanController, didPagingFromIndex fromIndex: Int, toIndex: Int) {
        print("panController(fromIndex: \(fromIndex), toIndex: \(toIndex)) ")
        self.segmentedControl.selectedSegmentIndex = toIndex
    }

}


//
// PanControllerTransformer のサンプル.
//
class ParallaxTransitionTransform: PanControllerTransformer {
    func panController(_ panController: PanController, views: [UIView], panningFromIndex fromIndex: Int, toIndex: Int, progress: CGFloat) {

        let dx: CGFloat = panController.scrollDirection == .horizontal ? (panController.view.frame.size.width / 2) : 0
        let dy: CGFloat = panController.scrollDirection == .vartical ? (panController.view.frame.size.height / 2) : 0

        views[1].superview?.bringSubview(toFront: views[1])
        
        switch panController.panningDirection {
        case .previous:
            views[0].transform = CGAffineTransform(translationX: dx * (1 - progress) , y: dy * (1 - progress))
            views[2].transform = CGAffineTransform.identity

            views[1].layer.shadowColor = UIColor.black.cgColor
            views[1].layer.shadowRadius = (1 - progress) * 10
            views[1].layer.shadowOpacity = 1

        case .next:
            views[0].transform = CGAffineTransform.identity
            views[2].transform = CGAffineTransform(translationX: dx * (progress - 1) , y: dy * (progress - 1))

            views[1].layer.shadowColor = UIColor.black.cgColor
            views[1].layer.shadowRadius = (1 - progress) * 10
            views[1].layer.shadowOpacity = 1

        default:
            views[1].transform = CGAffineTransform.identity
            views[1].layer.shadowColor = UIColor.clear.cgColor
            views[1].layer.shadowRadius = 0
            views[1].layer.shadowOpacity = 0
        }
    }
    func panControllerWillRemoveTransformer(_ panController: PanController, views: [UIView]) {
        views.forEach {
            $0.transform = CGAffineTransform.identity
        }
        views[1].layer.shadowColor = UIColor.clear.cgColor
        views[1].layer.shadowRadius = 0
        views[1].layer.shadowOpacity = 0
    }
}

//
// PanControllerTransformer のサンプル.
//
class CardStackTransitionTransform: PanControllerTransformer {
    func panController(_ panController: PanController, views: [UIView], panningFromIndex fromIndex: Int, toIndex: Int, progress: CGFloat) {
        
        let dx: CGFloat = panController.scrollDirection == .horizontal ? panController.view.frame.size.width : 0
        let dy: CGFloat = panController.scrollDirection == .vartical ? panController.view.frame.size.height : 0

        switch panController.panningDirection {
        case .previous:
            let scale = (1-progress) * 0.3 + 0.7
            views[0].superview?.bringSubview(toFront: views[0])
            views[1].transform = CGAffineTransform(translationX: dx * -progress , y: dy * -progress).scaledBy(x: scale, y: scale)
            views[0].transform = CGAffineTransform.identity
            views[0].alpha = 1
            views[1].alpha = 1 - progress
        case .next:
            let scale = progress * 0.3 + 0.7
            views[1].superview?.bringSubview(toFront: views[1])
            views[2].transform = CGAffineTransform(translationX: dx * (progress - 1) , y: dy * (progress - 1)).scaledBy(x: scale, y: scale)
            views[1].transform = CGAffineTransform.identity
            views[1].alpha = 1
            views[2].alpha = progress
        default:
            views[1].transform = CGAffineTransform.identity
            views[1].alpha = 1
        }
    }
    func panControllerWillRemoveTransformer(_ panController: PanController, views: [UIView]) {
        views.forEach {
            $0.transform = CGAffineTransform.identity
        }
        panController.scrollView.layer.sublayerTransform.m34 = 0
    }
}


//
// PanControllerTransformer のサンプル.
//
class FlipTransitionTransform: PanControllerTransformer {
    
    var flip: CGFloat = 1
    
    convenience init (_ flipRate: CGFloat) {
        self.init()
        flip = flipRate
    }

    func panController(_ panController: PanController, views: [UIView], panningFromIndex fromIndex: Int, toIndex: Int, progress: CGFloat) {
        panController.scrollView.layer.sublayerTransform.m34 = -1.0 / 600;
        let x: CGFloat = panController.scrollDirection == .horizontal ? 0 : 1
        let y: CGFloat = panController.scrollDirection == .horizontal ? 1 : 0
        let r: CGFloat = panController.scrollDirection == .horizontal ? flip : -flip
        
        switch panController.panningDirection {
        case .previous:
            views[0].layer.transform = CATransform3DMakeRotation((1 - progress) * r, x, y, 0)
            views[1].layer.transform = CATransform3DMakeRotation(-progress * r, x, y, 0)
            views[2].layer.transform = CATransform3DIdentity
        case .next:
            views[0].layer.transform = CATransform3DIdentity
            views[1].layer.transform = CATransform3DMakeRotation(progress * r, x, y, 0)
            views[2].layer.transform = CATransform3DMakeRotation((progress - 1) * r, x, y, 0)
        default:
            views[1].layer.transform = CATransform3DIdentity
        }
        
        views[0].alpha = panController.panningDirection == .previous ? progress : 0
        views[1].alpha = 1 - progress
        views[2].alpha = panController.panningDirection == .next ? progress : 0
    }
    func panControllerWillRemoveTransformer(_ panController: PanController, views: [UIView]) {
        views.forEach {
            $0.layer.transform = CATransform3DIdentity
            $0.alpha = 1.0
        }
        panController.scrollView.layer.sublayerTransform.m34 = 0
    }
}

//
// PanControllerTransformer のサンプル.
//
class RotateTransitionTransform: PanControllerTransformer {
    func panController(_ panController: PanController, views: [UIView], panningFromIndex fromIndex: Int, toIndex: Int, progress: CGFloat) {
        let r: CGFloat = panController.scrollDirection == .horizontal ? 1 : -1
        switch panController.panningDirection {
        case .previous:
            views[0].layer.transform = CATransform3DMakeRotation((1 - progress) * r, 0, 0, 1)
            views[1].layer.transform = CATransform3DMakeRotation(-progress * r, 0, 0, 1)
            views[2].layer.transform = CATransform3DIdentity
        case .next:
            views[0].layer.transform = CATransform3DIdentity
            views[1].layer.transform = CATransform3DMakeRotation(progress * r, 0, 0, 1)
            views[2].layer.transform = CATransform3DMakeRotation((progress - 1) * r, 0, 0, 1)
        default:
            views[1].layer.transform = CATransform3DIdentity
        }
        views[0].alpha = panController.panningDirection == .previous ? progress : 0
        views[1].alpha = 1 - progress
        views[2].alpha = panController.panningDirection == .next ? progress : 0
    }

    func panControllerWillRemoveTransformer(_ panController: PanController, views: [UIView]) {
        views.forEach {
            $0.layer.transform = CATransform3DIdentity
            $0.alpha = 1.0
        }
    }
}
