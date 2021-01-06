//
//  ConfettiType.swift
//  PoseEstimation-CoreML
//
//  Created by John Baer on 1/5/21.
//  Copyright © 2021 tucan9389. All rights reserved.
//

import Foundation
import UIKit


class ConfettiType {
    let color: UIColor
    let shape: ConfettiShape
    let position: ConfettiPosition

    init(color: UIColor, shape: ConfettiShape, position: ConfettiPosition) {
        self.color = color
        self.shape = shape
        self.position = position
    }
    
    lazy var image: UIImage = {
            let imageRect: CGRect = {
                switch shape {
                case .rectangle:
                    return CGRect(x: 0, y: 0, width: 20, height: 13)
                case .circle:
                    return CGRect(x: 0, y: 0, width: 10, height: 10)
                }
            }()

            UIGraphicsBeginImageContext(imageRect.size)
            let context = UIGraphicsGetCurrentContext()!
            context.setFillColor(color.cgColor)

            switch shape {
            case .rectangle:
                context.fill(imageRect)
            case .circle:
                context.fillEllipse(in: imageRect)
            }

            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return image!
        }()
}

enum ConfettiShape {
    case rectangle
    case circle
}

enum ConfettiPosition {
    case foreground
    case background
}
