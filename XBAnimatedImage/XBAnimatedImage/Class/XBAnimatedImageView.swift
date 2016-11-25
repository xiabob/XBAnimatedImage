//
//  XBAnimatedImageView.swift
//  XBAnimatedImage
//
//  Created by xiabob on 16/11/24.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit
import ImageIO

fileprivate let kDefaultMemoryLimitMB = 20

open class XBAnimatedImageView: UIImageView {
    var needToPlay = true
    var memoryLimitMB = 0
    var timer: CADisplayLink?
    var animatedImage: XBAnimatedImage
    var displayOrderIndex = 0
    var currentImage: UIImage?
    var cache = NSCache<AnyObject, AnyObject>()
    var processedQueue = DispatchQueue.global(priority: .high)
    var firstFrameImage: UIImage? {
        guard let isrc = animatedImage.animatedImageSource else {return nil}
        guard let cgImage = CGImageSourceCreateImageAtIndex(isrc, 0, nil) else {return nil}
        return UIImage(cgImage: cgImage)
    }
    
    ///动画重复播放次数。默认值0，表示没有限制
    open var repeatCount: Int = 0
    
    //MARK: - Init
    
    public init(animatedImage: XBAnimatedImage, memoryLimitMB: Int = kDefaultMemoryLimitMB) {
        self.animatedImage = animatedImage
        
        super.init(image: nil)
        
        setAnimatedImage(animatedImage: animatedImage, memoryLimitMB: memoryLimitMB)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func setAnimatedImage(animatedImage: XBAnimatedImage, memoryLimitMB: Int = kDefaultMemoryLimitMB) {
        self.animatedImage = animatedImage
        self.memoryLimitMB = memoryLimitMB
        
        currentImage = firstFrameImage
        
        if animatedImage.isGif {
            configTimer()
        }
        self.image = currentImage
    }
    
    func configTimer() {
        if animatedImage.animatedImageSizeMB > memoryLimitMB {
            timer = CADisplayLink(target: self, selector: #selector(updateFrameWithoutCache))
        } else {
            processedQueue.async(execute: {
                self.prepareCache()
            })
            timer = CADisplayLink(target: self, selector: #selector(updateFrameWithCache))
        }
        
        
        timer?.frameInterval = animatedImage.animatedImageDisplayRefreshFactor
        timer?.add(to: RunLoop.main, forMode: .commonModes)
    }
    
    //MARK: - Logic
    
    func prepareCache() {
        guard let isrc = self.animatedImage.animatedImageSource else {return}
        
        for index in 0..<(animatedImage.animatedImageDisplayOrder.count){
            let order = self.animatedImage.animatedImageDisplayOrder[index]
            guard let cgImage = CGImageSourceCreateImageAtIndex(isrc, order, [(kCGImageSourceShouldCacheImmediately as String): kCFBooleanTrue] as CFDictionary) else {return}
            let image = UIImage(cgImage: cgImage)
            cache.setObject(image, forKey: index as AnyObject)
        }
    }
    
    func updateFrameWithCache() {
        if needToPlay {
            self.image = cache.object(forKey: displayOrderIndex as AnyObject) as? UIImage
            displayOrderIndex = (self.displayOrderIndex + 1) % self.animatedImage.animatedImageCount
            checkRepeatStatus()
        }
    }
    
    func updateFrameWithoutCache() {
        if(needToPlay){
            self.image = currentImage
            processedQueue.async(execute: {
                guard let isrc = self.animatedImage.animatedImageSource else {return}
                let order = self.animatedImage.animatedImageDisplayOrder[self.displayOrderIndex]
                guard let cgImage = CGImageSourceCreateImageAtIndex(isrc, order, [(kCGImageSourceShouldCacheImmediately as String): kCFBooleanTrue] as CFDictionary) else {return}
                self.currentImage = UIImage(cgImage: cgImage)
                
                self.displayOrderIndex = (self.displayOrderIndex + 1) % self.animatedImage.animatedImageCount
                self.checkRepeatStatus()
            })
        }
    }
    
    func checkRepeatStatus() {
        if self.displayOrderIndex == 0 {
            let workItem = {
                if self.repeatCount == 1 {
                    self.stopAnimating()
                    self.currentImage = self.firstFrameImage
                    self.image = self.currentImage
                } else if self.repeatCount > 1 {
                    self.repeatCount -= 1
                }
            }
            
            if Thread.isMainThread {
                workItem()
            } else {
                DispatchQueue.main.async(execute: {
                    workItem()
                })
            }
        }
    }
    
    open override func startAnimating() {
        if animatedImage.isGif {
            needToPlay = true
            configTimer()
        } else {
            super.startAnimating()
        }
    }
    
    open override func stopAnimating() {
        if animatedImage.isGif {
            needToPlay = false
            timer?.invalidate()
        } else {
            super.stopAnimating()
        }
    }
    
}
