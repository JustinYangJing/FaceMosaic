//
//  ViewController.swift
//  FaceMosaic
//
//  Created by JustinYang on 2021/4/18.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    lazy var session : AVCaptureSession = {
        return AVCaptureSession()
    }()
    lazy var glview : GLView  = {
        var view = GLView(frame: self.view.bounds)
        return view
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        AVCaptureDevice.requestAccess(for: .video) { (flag) in
            if flag == true{
                self.setupVideo()
            }

        }
        view.addSubview(self.glview)
    /*渲染图片
        let buf = self.imageToCVPixelBufferRef(UIImage.init(named: "frame_ori.jpg")!)
        let img = GLView.pixelBuffer(toImage: buf!)
        let imgView = UIImageView.init(image: img)
        imgView.sizeToFit()
        imgView.frame = self.view.bounds
        self.view.addSubview(imgView)
        self.glview.renderCVImageBuffer(buf!, normalsFaceBounds: [CGRect(x: 0.4, y: 0.35, width: 0.30, height: 0.35)])
 */
        
//        printGussPeriod()
        
    }
    
    func setupVideo() {
        
        
        session.sessionPreset = .hd1280x720
        
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput.init(device: videoDevice){
            videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            session.addInput(input)
            
        }else{
            assert(true, "初始化失败")
        }
        
        let output = AVCaptureVideoDataOutput()
        session.addOutput(output)
        
        let videoOutputQueue = DispatchQueue.init(label: "videoOutputQueue")
        
        output.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        output.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey):kCVPixelFormatType_32BGRA]
        output.connections.forEach { (con) in
            con.isVideoMirrored = false
            con.videoOrientation = .portraitUpsideDown
        }
        //    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange

        
        
        session.startRunning()
    }
    
    /// 打印半径为5的高斯函数的像素点的权重,高斯权函数G(x,y) = 1/(2*pi*σ^2) * e^(-(x^2 + y^2)/(2*σ^2))
    func printGussPeriod(){
        print("e1:\(exp(1.0))")
        var guss = [Double]()
        let sigma = 100.0
        
        for row in [5,4,3,2,1,0,-1,-2,-3,-4,-5]{
            for col in -5...5 {
                let value = 1/(2 * Double.pi * sigma*sigma) * exp(-(pow(Double(col), 2) + pow(Double(row), 2))/(2*sigma*sigma))
                guss.append(value)
            }
        }
      
        let sum : Double = guss.reduce(0.0) { (x, y) -> Double in
            return x + y
        }
       let finalGuss = guss.map { (ele) -> Float in
                return Float(ele/sum)
            }
    
        var str = ""
        for i in 0..<finalGuss.count{
            str = str + "\(finalGuss[i]),  "
            if (i+1)%11 == 0 {
                str = str + "\n\n"
            }
        }
        print("\(str)")
        
        var offsets = [(Float,Float)]()
        for row in [5,4,3,2,1,0,-1,-2,-3,-4,-5]{
            for col in -5...5 {
                let ele = (Float(col)/200,Float(row)/200)
                offsets.append(ele)
            }
        }
        str = ""
        offsets.forEach { (ele) in
            str = str + "vec2(\(ele.0),\(ele.1)),"
        }
        print("\(str)")
    }
}

//MARK: AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController:AVCaptureVideoDataOutputSampleBufferDelegate{
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
   
        guard let buf = CMSampleBufferGetImageBuffer(sampleBuffer) else { return}
        
        /// 1.新建侦测人脸request
        let request = VNDetectFaceLandmarksRequest { (req, err) in
            /// 4.得到处理结果：req.result即是识别出来的人脸
            guard let results = req.results else {return }
            var faceBounds :[CGRect] = []
            for ob in results{
                if let ob = ob as? VNFaceObservation {
                    /// boundingBox是识别出来的人脸框，以左下角为原点，值是0~1范围内，这里与视频的方向对应上了，所有不需要转化，传入shader中直接可与纹理坐标比较
                    faceBounds.append(ob.boundingBox)
                }
            }
            DispatchQueue.main.async {
                self.glview.renderCVImageBuffer(buf, normalsFaceBounds: faceBounds)
            }
        }
        
        /// 2.新建处理handler,注意orientation的值和在设置数据输出时设置的视频的方向
        let handler = VNImageRequestHandler(cvPixelBuffer: buf, orientation: .downMirrored)
        do {
            /// 3.发起人脸识别
            try handler.perform([request])
        } catch let err {
            
        }
    }
}
extension ViewController{
    
    /// UIImage转化为CVPixelBuffer
    /// - Parameter image: UIImage
    /// - Returns:CVPixelBuffer
    func imageToCVPixelBufferRef(_ image: UIImage) -> CVPixelBuffer?{
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
          var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
          guard (status == kCVReturnSuccess) else {
            return nil
          }

          CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
          let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

          let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedFirst.rawValue)
        
//          context?.translateBy(x: 0, y: image.size.height)
//          context?.scaleBy(x: 1.0, y: -1.0)

          UIGraphicsPushContext(context!)
          image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
          UIGraphicsPopContext()
          CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

          return pixelBuffer
    }
    
}



