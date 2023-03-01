//
//  Tool.swift
//  
//
//  Created by 成璐飞 on 2023/2/27.
//

import UIKit

extension Double {
    /// 总时长（秒） -> 展示文字
    public func toVideoDisplayText() -> String {
        let minute: Int = Int((self / 60).rounded(.towardZero))
        let hour: Int = Int((Double(minute) / 60.0).rounded(.towardZero))
        let second: Int = Int(self.truncatingRemainder(dividingBy: 60).rounded(.towardZero))
        let tetx = (hour > 0 ? ("\(hour)" + ":") : "")
                    + String(format: "%02d", minute)
                    + ":" + String(format: "%02d", second)
        return tetx
    }
}

extension UIImage {
    // 工厂方法
    static func tintWhiteImageWith(systemName: String) -> UIImage? {
        return UIImage(systemName: systemName)?.withTintColor(.white, renderingMode: .alwaysOriginal)
    }
}
