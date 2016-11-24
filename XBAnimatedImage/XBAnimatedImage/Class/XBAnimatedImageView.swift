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
    var timer: CADisplayLink?
    var animatedImage: XBAnimatedImage
    var displayOrderIndex = 0
    var currentImage: UIImage?
    var cache = NSCache<AnyObject, AnyObject>()
    var processedQueue = DispatchQueue.global(priority: .high)
    
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
        guard let isrc = animatedImage.animatedImageSource else {return}
        guard let cgImage = CGImageSourceCreateImageAtIndex(isrc, 0, nil) else {return}
        currentImage = UIImage(cgImage: cgImage)
        
        if animatedImage.isGif {
            if (animatedImage.animatedImageSizeMB ?? 0) > kDefaultMemoryLimitMB {
                timer = CADisplayLink(target: self, selector: #selector(updateFrameWithoutCache))
            } else {
                processedQueue.async(execute: { 
                    self.prepareCache()
                })
                timer = CADisplayLink(target: self, selector: #selector(updateFrameWithCache))
            }
            
            
            timer?.frameInterval = animatedImage.animatedImageDisplayRefreshFactor ?? 1
            timer?.add(to: RunLoop.main, forMode: .commonModes)
        } else {
            self.image = currentImage
        }
    }
    
    
    func prepareCache() {
        guard let isrc = self.animatedImage.animatedImageSource else {return}
        
        for index in 0..<(animatedImage.animatedImageDisplayOrder?.count ?? 0){
            let order = self.animatedImage.animatedImageDisplayOrder![index]
            guard let cgImage = CGImageSourceCreateImageAtIndex(isrc, order, [(kCGImageSourceShouldCacheImmediately as String): kCFBooleanTrue] as CFDictionary) else {return}
            let image = UIImage(cgImage: cgImage)
            cache.setObject(image, forKey: index as AnyObject)
        }
    }
    
    func updateFrameWithCache() {
        if needToPlay {
            self.image = cache.object(forKey: displayOrderIndex as AnyObject) as? UIImage
            self.displayOrderIndex = (self.displayOrderIndex + 1) % self.animatedImage.animatedImageCount!
        }
    }
    
    func updateFrameWithoutCache() {
        if(needToPlay){
            self.image = currentImage
            processedQueue.sync(execute: {
                guard let isrc = self.animatedImage.animatedImageSource else {return}
                let order = self.animatedImage.animatedImageDisplayOrder![self.displayOrderIndex]
                guard let cgImage = CGImageSourceCreateImageAtIndex(isrc, order, [(kCGImageSourceShouldCacheImmediately as String): kCFBooleanFalse] as CFDictionary) else {return}
                self.currentImage = UIImage(cgImage: cgImage)
                
                self.displayOrderIndex = (self.displayOrderIndex + 1) % self.animatedImage.animatedImageCount!
            })
        }
    }
}
