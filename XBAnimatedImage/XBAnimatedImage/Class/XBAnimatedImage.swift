//
//  XBAnimatedImage.swift
//  XBAnimatedImage
//
//  Created by xiabob on 16/11/24.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit
import ImageIO
import MobileCoreServices

fileprivate let kDefaultFluency: Float = 0.8 //默认gif展示的流畅度，1是最好
fileprivate let kDefaultPlayRate: Float = 1
fileprivate let kFloatEPS: Float = 1E-6 //float的精度
fileprivate let kFrameFactor = [60, 30, 20, 15, 12, 10, 6, 5, 4, 3, 2, 1] //gif展示最大60帧，这是60的全部因子

fileprivate let kAnimatedImageProperties = "kAnimatedImageProperties"

open class XBAnimatedImage: UIImage {
    
    //MARK: - Var
    private var animatedImageProperties: AnimatedImageProperties?
    public var animatedImageSource: CGImageSource? {return animatedImageProperties?.imageSource}
    public var animatedImageDisplayRefreshFactor: Int {return animatedImageProperties?.displayRefreshFactor ?? 1}
    public var animatedImageSizeMB: Int {return animatedImageProperties?.imageSize ?? 0}
    public var animatedImageCount: Int {return animatedImageProperties?.imageCount ?? 1}
    public var animatedImageDisplayOrder: [Int] {return animatedImageProperties?.displayOrder ?? []}
    
    open var isGif = true
    open var animatedImageFluency: Float {return animatedImageProperties?.fluency ?? kDefaultFluency}
    
    //MARK: - Init
    
    /// 设置image，imageData是图片数据，fluency设置gif展示的质量，0<fluency<=1
    public init(imageData: Data, fluency: Float = kDefaultFluency) {
        super.init()
        setAnimatedImage(imageData: imageData, fluency: fluency)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required convenience public init(imageLiteralResourceName name: String) {
        fatalError("init(imageLiteralResourceName:) has not been implemented")
    }
    
    /// 设置image，imageData是图片数据，fluency设置gif展示的质量，0<fluency<=1
    open func setAnimatedImage(imageData: Data, fluency: Float = kDefaultFluency) {
        animatedImageProperties = AnimatedImageProperties()
        animatedImageProperties?.imageSource = CGImageSourceCreateWithData(imageData as CFData, nil)
        let imageSourceContainerType = CGImageSourceGetType(animatedImageProperties!.imageSource!) ?? "" as CFString
        isGif = UTTypeConformsTo(imageSourceContainerType, kUTTypeGIF)
        
        if isGif {
            animatedImageProperties?.fluency = fluency
            
            if fluency <= 0 || fluency > 1 {
                debugPrint("Illegal input parameter: 0<fluency<=1")
                calculateDelayFrame(delayTimes: calculateDelayTimes(imageSource: animatedImageSource), fluency: kDefaultFluency)
            } else {
                calculateDelayFrame(delayTimes: calculateDelayTimes(imageSource: animatedImageSource), fluency: fluency)
            }
            
            calculateFrameSize()
        }
    }
    
    //MARK: - Logic Method
    
    private func calculateDelayTimes(imageSource: CGImageSource?) -> [Float] {
        guard let imageSource = imageSource else {return []}
        
        let imageCount = CGImageSourceGetCount(imageSource)
        var imageProperties = [CFDictionary]()
        for index in 0..<imageCount {
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, nil)
            if let properties = properties  {
                imageProperties.append(properties)
            } else {
                continue
            }
        }
        
        var frameProperties = [CFDictionary]()
        if isGif {
            frameProperties = imageProperties.map {
                unsafeBitCast(CFDictionaryGetValue($0, Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()), to: CFDictionary.self)
            }
        } else {
            fatalError("not a gif image")
        }
        
        let frameDelayTimes: [Float] = frameProperties.map {
            var delayNumber = unsafeBitCast(CFDictionaryGetValue($0, Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()), to: NSNumber.self)
            if delayNumber.floatValue < kFloatEPS {
                delayNumber = unsafeBitCast(CFDictionaryGetValue($0, Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: NSNumber.self)
            }
            
            //这是每一张图片展示的时间
            return ((delayNumber.floatValue < kFloatEPS) ? 0.1 : delayNumber.floatValue)
        }
        
        return frameDelayTimes
    }
    
    private func calculateDelayFrame(delayTimes: [Float], fluency: Float) {
        var delays = delayTimes
        
        let maxFPS = kFrameFactor.first ?? 60
        //不同因子下fps值
        let displayRefreshRates = kFrameFactor.map {
            return maxFPS / $0
        }
        
        //不同fps值下，每一帧的时间
        let displayRefreshDelayTime = displayRefreshRates.map {
            return 1.0 / Float($0)
        }
        
        //计算每一张图片展示的时间
        for index in 1..<delays.count {
            delays[index] += delays[index-1]
        }
        
        //找到适合展示gif的帧数，这是基于cpu、内存占用考虑的，就是在质量和性能上找平衡
        for index in 0..<displayRefreshDelayTime.count {
            let displayPositions = delays.map {
                return Int($0 / displayRefreshDelayTime[index])
            }
            
            //丢弃的帧数
            var frameLoseCount = 0
            for position in 1..<displayPositions.count {
                //两张图片间隔时间小于一帧的时间就丢弃
                if displayPositions[position] == displayPositions[position-1] {
                    frameLoseCount += 1
                }
            }
            
            //找到合适的值了
            if Float(frameLoseCount) <= Float(displayPositions.count) * (1-fluency) ||
                index == displayRefreshDelayTime.count-1 {
                animatedImageProperties?.imageCount = displayPositions.last
                animatedImageProperties?.displayRefreshFactor = kFrameFactor[index]
                
                var displayOrder = [Int]()
                var indexOfold = 0, indexOfnew = 0
                while indexOfnew <= animatedImageProperties?.imageCount ?? 0 {
                    if indexOfnew <= displayPositions[indexOfold] {
                        indexOfnew += 1
                        displayOrder.append(indexOfold)
                    } else {
                        indexOfold += 1
                    }
                }
                animatedImageProperties?.displayOrder = displayOrder
                break
            }
        }
    }
    
    private func calculateFrameSize() {
        guard let isrc = animatedImageProperties?.imageSource else {return}
        guard let cgImage = CGImageSourceCreateImageAtIndex(isrc, 0, nil) else {return}
        let image = UIImage(cgImage: cgImage)
        animatedImageProperties?.imageSize = Int(image.size.width*image.size.height*4) * animatedImageProperties!.imageCount! / (1000*1000)
    }
}

fileprivate class AnimatedImageProperties {
    var imageSource: CGImageSource?
    var displayRefreshFactor: Int? //刷新因数 == CADisplayLink.frameInterval
    var imageSize: Int?  //动图文件大小，单位是MB
    var imageCount: Int? //动图包含的图片张数
    var displayOrder: [Int]? //图片展示的次序
    var fluency: Float = kDefaultFluency //图片质量，fluency设置gif展示的质量，0<fluency<=1
}

