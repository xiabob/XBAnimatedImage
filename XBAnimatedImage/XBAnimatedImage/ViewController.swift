//
//  ViewController.swift
//  XBAnimatedImage
//
//  Created by xiabob on 16/11/24.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            let imageData = try Data(contentsOf: Bundle.main.url(forResource: "2", withExtension: "gif")!, options: [])
            let image = XBAnimatedImage(imageData: imageData, fluency: 1)
            let imageView = XBAnimatedImageView(animatedImage: image)
            imageView.frame = CGRect(x: 0.0, y: 0.0, width: view.frame.width, height: view.frame.height)
            imageView.contentMode = .scaleAspectFit
            view.addSubview(imageView)
        } catch {
            
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

