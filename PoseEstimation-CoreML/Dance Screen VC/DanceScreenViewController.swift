//
//  DanceScreenViewController.swift
//  PoseEstimation-CoreML
//
//  Created by John Baer on 12/26/20.
//  Copyright © 2020 tucan9389. All rights reserved.
//

import UIKit

class DanceScreenViewController: UIViewController {

    
    
    
    var predictionsInOrder: [[Int:(CGFloat, CGFloat)?]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print(predictionsInOrder[0])

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
