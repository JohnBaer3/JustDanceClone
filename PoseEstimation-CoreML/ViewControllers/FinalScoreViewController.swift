//
//  FinalScoreViewController.swift
//  PoseEstimation-CoreML
//
//  Created by John Baer on 1/2/21.
//  Copyright © 2021 tucan9389. All rights reserved.
//

import UIKit

class FinalScoreViewController: UIViewController {

    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var accuracyLabel: UILabel!
    @IBOutlet weak var streakLabel: UILabel!
    @IBOutlet weak var continueButton: UIButton!
    
    var finalScore: CGFloat = 0.0
    var maxStreak = 0
    var accuracy: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scoreLabel.text = String(Int(finalScore))
        accuracyLabel.text = String(Int(accuracy)) + "%"
        streakLabel.text = String(maxStreak)
        
        setUpViews()
    }
    
    
    func setUpViews(){
        continueButton.alpha = 0
        
        continueButton.backgroundColor = UIColor(red: 29/255.0, green: 105/255.0, blue: 153/255.0, alpha: 1)
        continueButton.layer.cornerRadius = 20
        continueButton.layer.borderColor = UIColor.white.cgColor
        continueButton.layer.borderWidth = 1
        continueButton.clipsToBounds = true
        
        UIButton.animate(withDuration: 1.0, delay: 4.0, options: .curveEaseOut, animations: { [weak self] in
            self?.continueButton.alpha = 1.0
        }, completion: nil)
    }
    
    


}
