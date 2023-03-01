//
//  DismissTransition.swift
//  
//
//  Created by 成璐飞 on 2023/2/28.
//

import UIKit

class DismissTransition: NSObject, UIViewControllerAnimatedTransitioning {
    var isPresent = true
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.25
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        let backView = UIView(frame: container.frame)
        backView.backgroundColor = .black
        backView.alpha = 0.15
        if isPresent {
            guard let fromVC = transitionContext.viewController(forKey: .from),
                  let toVC = transitionContext.viewController(forKey: .to),
                  let fromView = fromVC.view,
                  let toView = toVC.view else { return }
            toView.frame = CGRect(x: 0, y: UIScreen.main.bounds.size.height,
                                   width: UIScreen.main.bounds.size.width,
                                   height: UIScreen.main.bounds.size.height)
            container.addSubview(fromView)
            container.addSubview(backView)
            container.addSubview(toView)
            
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext)) {
                toView.frame = CGRect(x: 0, y: 0,
                                      width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height)
            } completion: { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        } else {
            guard let fromVC = transitionContext.viewController(forKey: .from),
                  let toVC = transitionContext.viewController(forKey: .to),
                  let fromView = fromVC.view,
                  let toView = toVC.view else { return }
            fromView.frame = CGRect(x: 0, y: 0,
                                     width: UIScreen.main.bounds.size.width,
                                     height: UIScreen.main.bounds.size.height)
            container.addSubview(toView)
            container.addSubview(backView)
            container.addSubview(fromView)
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext)) {
                backView.alpha = 0
                fromView.frame = CGRect(x: 0, y: UIScreen.main.bounds.size.height,
                                         width: UIScreen.main.bounds.size.width,
                                         height: UIScreen.main.bounds.size.height)
            } completion: { _ in
                if !transitionContext.transitionWasCancelled {
                    backView.removeFromSuperview()
                }
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
    
    func reloadWithPresent(isPresent: Bool) -> DismissTransition {
        self.isPresent = isPresent
        return self
    }  
}
