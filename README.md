# XBAnimatedImage
A animated gif engine for iOS in Swift inspired by [AImage](https://github.com/wangjwchn/AImage) and [FLAnimatedImage](https://github.com/Flipboard/FLAnimatedImage)
![image](https://github.com/xiabob/XBAnimatedImage/blob/master/Images/sam.gif)
##要求
iOS7+，xcode8.1+，swift 3
##使用
基本使用
<pre>
let imageData = try Data(contentsOf: Bundle.main.url(forResource: "2", withExtension: "gif")!, options: [])
let image = XBAnimatedImage(imageData: imageData)
imageView = XBAnimatedImageView(animatedImage: image)
imageView?.frame = CGRect(x: 0.0, y: 0.0, width: view.frame.width, height: view.frame.height)
view.addSubview(imageView!)
</pre>
具体的功能请看[demo代码](https://github.com/xiabob/XBAnimatedImage/blob/master/XBAnimatedImage/XBAnimatedImage/ViewController.swift)
