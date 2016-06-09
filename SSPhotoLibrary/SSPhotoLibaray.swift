//
//  SSPhotoLibrary.swift
//
//  Created by Steeven Sylveus on 2/20/16.
//  Copyright © 2016 Steeven Sylveus. All rights reserved.
//

import UIKit
import Photos
import AVKit

protocol SSPhotoLibraryDelegate {
    
    func didFinishPickingImageAsset(asset: PHAsset, withCroppedImage image: UIImage)
    func didFinishPickingVidoAsset(asset: AVAsset, withVideoUrl url: NSURL, withVideoImage image: UIImage)
}

class SSPhotoLibaray: UIViewController {
    
    var delegate: SSPhotoLibraryDelegate? = nil
    var hideVideos: Bool = true
    var themeColor: UIColor? = nil
    
    //Private variables
    private var photoAssetReslt: PHFetchResult? = nil
    private var videoAssestResult: PHFetchResult? = nil
    private var assetCollection: PHAssetCollection = PHAssetCollection()
    private var assetImageView: UIImageView? = UIImageView()
    private var imageManager: PHCachingImageManager = PHCachingImageManager()
    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var scrollView: UIScrollView!
    private var scrollViewZoomScalle: CGFloat? = nil
    @IBOutlet private var segmentedControl: UISegmentedControl!
    private var processingVideo: Bool = false
    private var videoData: NSData? = nil
    @IBOutlet private var bottomSeperatorView: UIView!
    @IBOutlet private var topHeaderView: UIView!
    @IBOutlet private var noDataFoundLabel: UILabel!
    private var selectedAsset: PHAsset = PHAsset()
    @IBOutlet private var closeBtn: UIButton!
    private var playerViewController: AVPlayerViewController? = nil
    private var player: AVPlayer? = nil
    @IBOutlet private var videoContainer: UIView!
    private var videoAsset: PHAsset? = nil
    private var exporter: AVAssetExportSession? = nil
    private var defaultThemeColor: UIColor = UIColor.greenAppColor()
    
    private let sortDescriptor: String = "creationDate"
    private let noPhotoFound = "No Photos Found";
    private let noVideoFound = "No Videos Found";
    private let segueIdentifier =  "AVPlayerVC"
    private let cellIdentifier = "SSPhotoCells"
    
    private let collectionImageViewSize: CGFloat = 102.0
    private let selectedAssetImageSize: CGFloat =  616
    
    //Mark -  VC Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if hideVideos {
            segmentedControl?.hidden = true
        } else {
            segmentedControl?.hidden = false
        }
        
        scrollView.delegate = self
        requestLibraryAuthorization()
        
        UIApplication.sharedApplication().statusBarHidden = true
        setNeedsStatusBarAppearanceUpdate()
        
        defaultThemeColor = themeColor != nil ? themeColor! : UIColor.greenAppColor()
        setThemeColor()

    }
    
    override func viewWillDisappear(animated: Bool) {
        UIApplication.sharedApplication().statusBarHidden = false
        setNeedsStatusBarAppearanceUpdate()
        super.viewWillDisappear(animated)
    }
    
    func setThemeColor() {
        topHeaderView.backgroundColor = defaultThemeColor
        bottomSeperatorView.backgroundColor = defaultThemeColor
    }
    
    func requestLibraryAuthorization() {
        PHPhotoLibrary.requestAuthorization { (status) -> Void in
            if status == .Authorized {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.showAssetsBaseOnSegmentIndex(index: self.segmentedControl.selectedSegmentIndex)
                })
            }
        }
    }
    
    //Mark - Prepare for Segue
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == segueIdentifier {
            playerViewController = segue.destinationViewController as? AVPlayerViewController
        }
    }
    
    //MARK - PhotoKit Framework
    func showAssetsBaseOnSegmentIndex(index index: Int) {
        player?.pause()
        player = nil
        videoAsset = nil
        
        switch index {
        case 0:
            retrievePhotoAssetResult()
            view.bringSubviewToFront(scrollView)
        case 1:
            retrieveVideoAssetResult()
            view.sendSubviewToBack(scrollView)
        default:
            break
        }
    }
    
    func retrievePhotoAssetResult() {
        let options: PHFetchOptions = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: sortDescriptor, ascending: false)]
        
        photoAssetReslt = PHAsset.fetchAssetsWithMediaType(.Image, options: options)
        processFetchResultData(photoAssetReslt!)
    }
    
    func retrieveVideoAssetResult() {
        let options: PHFetchOptions = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: sortDescriptor, ascending: false)]
        
        videoAssestResult = PHAsset.fetchAssetsWithMediaType(.Video, options: options)
        processFetchResultData(videoAssestResult!)
    }
    
    func processFetchResultData(result: PHFetchResult) {
        
        if result.count > 0 {
            collectionView(collectionView, didSelectItemAtIndexPath: NSIndexPath(forItem: 0, inSection: 0))
            noDataFoundLabel.hidden = true
        } else {
            assetImageView?.image = nil
            noDataFoundLabel.text = noPhotoFound
            noDataFoundLabel.hidden = false
        }

        collectionView.reloadData()
    }

    func retrievePlayerItem(phAsset phAsset: PHAsset) {
        videoData = nil
        videoContainer.layoutIfNeeded()
        
        PHImageManager.defaultManager().requestPlayerItemForVideo(phAsset,
            options: nil) { (playerItem, info) -> Void in
                if let item = playerItem {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.player = AVPlayer(playerItem: item)
                        self.playerViewController?.player = self.player
                        self.playerViewController?.videoGravity = AVLayerVideoGravityResizeAspect
                    })
                }
        }
    }
    
    func displayImage(image: UIImage) {
        // clear the previous image
        if assetImageView != nil {
            assetImageView?.removeFromSuperview()
            assetImageView = nil
            
            // reset our zoomScale to 1.0 before doing any further calculations
            self.scrollView.zoomScale = 1.0
            
            // make a new UIImageView for the new image
            assetImageView = UIImageView(image: image)
            assetImageView!.clipsToBounds = false
            scrollView.addSubview(assetImageView!)
            assetImageView!.contentMode = .ScaleAspectFit
            
            var frame: CGRect = self.assetImageView!.frame
            if image.size.height > image.size.width {
                frame.size.width = self.scrollView.bounds.size.width
                frame.size.height = (self.scrollView.bounds.size.width / image.size.width) * image.size.height
            }
            else {
                frame.size.height = self.scrollView.bounds.size.height
                frame.size.width = (self.scrollView.bounds.size.height / image.size.height) * image.size.width
            }
            
            assetImageView?.frame = frame
            configureForImageSize((assetImageView?.bounds.size)!)
        }
    }
    
    func configureForImageSize(imageSize: CGSize) {
        scrollView.contentSize = imageSize
        
        //to center
        if imageSize.width > imageSize.height {
            scrollView.contentOffset = CGPointMake(imageSize.width / 4, 0)
        } else if imageSize.width < imageSize.height {
            self.scrollView.contentOffset = CGPointMake(0, imageSize.height / 4)
        }
        
        setMaxMinZoomScalesForCurrentBounds()
        scrollView.zoomScale = self.scrollView.minimumZoomScale
    }
    
    func setMaxMinZoomScalesForCurrentBounds() {
        self.scrollView.minimumZoomScale = 1.0
        self.scrollView.maximumZoomScale = 2.0
    }
    
    //MARK - Cropping Calculationgs
    func takeSnapShot() -> UIImage {
        var visibleRect: CGRect = self.calcVisibleRectForCropArea()
        
        //caculate visible rect for crop
        let rectTransform: CGAffineTransform = self.orientationTransformedRectOfImage(assetImageView!.image!)
        
        //if need rotate caculate
        visibleRect = CGRectApplyAffineTransform(visibleRect, rectTransform)
        
        let ref: CGImageRef = CGImageCreateWithImageInRect(assetImageView!.image!.CGImage, visibleRect)!
        
        //crop
        let cropped: UIImage = UIImage(CGImage: ref, scale: assetImageView!.image!.scale, orientation: self.assetImageView!.image!.imageOrientation)
        
        return cropped
    }
    
    func orientationTransformedRectOfImage(img: UIImage) -> CGAffineTransform {
        var rectTransform: CGAffineTransform
        switch img.imageOrientation {
        case .Left:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(90.degreesToRadians), 0, -img.size.height)
        case .Right:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(-90.degreesToRadians), -img.size.width, 0)
        case .Down:
            rectTransform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(-180.degreesToRadians), -img.size.width, -img.size.height)
        default:
            rectTransform = CGAffineTransformIdentity
        }
        
        return CGAffineTransformScale(rectTransform, img.scale, img.scale)
    }
    
    func calcVisibleRectForCropArea() -> CGRect {
        var sizeScale: CGFloat = assetImageView!.image!.size.width / assetImageView!.frame.size.width
        sizeScale *= self.scrollView.zoomScale
        let visibleRect: CGRect = self.scrollView.convertRect(self.scrollView.bounds, toView: self.assetImageView)
        
        let calculateRect: CGRect = CGRectMake(visibleRect.origin.x * sizeScale, visibleRect.origin.y * sizeScale, visibleRect.size.width * sizeScale, visibleRect.size.height * sizeScale)

        return calculateRect
    }
    
    
    //MARK - Asset Info
    func retrievePlayerItemWithAsset(phAsset: PHAsset) {
        self.videoData = nil
        self.videoContainer.layoutIfNeeded()
        PHImageManager.defaultManager().requestPlayerItemForVideo(phAsset,
            options: nil,
            resultHandler: {(playerItem, info) -> Void in
            if let item = playerItem {
                dispatch_async(dispatch_get_main_queue(), {() -> Void in
                    self.player = AVPlayer(playerItem: item)
                    self.playerViewController!.player = self.player
                    self.playerViewController!.videoGravity = AVLayerVideoGravityResizeAspect
                })
            }
        })
    }
    
    func retrieveVideoUrlWithAsset(phAsset: PHAsset) {
        PHImageManager.defaultManager().requestAVAssetForVideo(phAsset,
            options: nil,
            resultHandler: {(asset, audioMix, info) -> Void in
            if (asset is AVURLAsset) {
                dispatch_async(dispatch_get_main_queue(), {() -> Void in
                    let urlAsset: AVURLAsset = asset as! AVURLAsset
                    if let thumbnail: UIImage = NSURL.thumbNailFromVideoURl(urlAsset.URL) {
                        self.delegate!.didFinishPickingVidoAsset(asset!, withVideoUrl: urlAsset.URL, withVideoImage: thumbnail)
                        self.dismissViewControllerAnimated(true, completion: { _ in })
                        
                    }
                })
                }
        })
    }
    
    
    //MARK - IBActions
    @IBAction func valueChanged(sender: AnyObject) {
        self.showAssetsBaseOnSegmentIndex(index: self.segmentedControl.selectedSegmentIndex)
    }
    
    @IBAction func selectBtnPressed(sender: AnyObject) {
        if (self.videoAsset != nil) {
            self.retrieveVideoUrlWithAsset(self.videoAsset!)
        }
        else {
            self.delegate?.didFinishPickingImageAsset(self.selectedAsset, withCroppedImage: self.takeSnapShot())
            self.dismissViewControllerAnimated(true, completion: { _ in })
        }
    }
    
    @IBAction func closeBtnPressed(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: { _ in })
    }

}

extension SSPhotoLibaray: UIScrollViewDelegate {
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return assetImageView
    }
    
    func scrollViewDidEndZooming(scrollView: UIScrollView, withView view: UIView?, atScale scale: CGFloat) {
        scrollViewZoomScalle = scale
    }
}

extension SSPhotoLibaray: UICollectionViewDelegateFlowLayout {
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSizeMake((view.bounds.size.width / 4) - 2, (view.bounds.size.width / 4) - 2)
    }
}

extension SSPhotoLibaray: UICollectionViewDataSource {
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if segmentedControl.selectedSegmentIndex == 0 {
            if let photos = photoAssetReslt {
                return photos.count
            } else {
                return 0
            }
        } else {
            if let videos = videoAssestResult {
                return videos.count
            } else {
                return 0
            }
        }
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as! SSPhotoCells
        
        let currentTag = cell.tag
        cell.tag = currentTag
        cell.layer.borderWidth = 1.0
        cell.layer.borderColor = defaultThemeColor.CGColor
        
        let asset = (segmentedControl.selectedSegmentIndex == 0 ? photoAssetReslt![indexPath.item] : videoAssestResult![indexPath.item]) as? PHAsset
        
        imageManager.requestImageForAsset(asset!,
            targetSize: CGSizeMake(collectionImageViewSize, collectionImageViewSize),
            contentMode: .AspectFill,
            options: nil) { (result, info) -> Void in
                
                if cell.tag == currentTag {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        cell.assetImageView.image = result
                        cell.tag = currentTag
                    })
                }
        }
        
        return cell
    }
}

extension SSPhotoLibaray: UICollectionViewDelegate {
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        assetImageView?.layoutIfNeeded()
        
        scrollView.contentInset = UIEdgeInsetsZero
        scrollView.contentSize = scrollView.bounds.size
        
        selectedAsset = (segmentedControl.selectedSegmentIndex == 0 ? photoAssetReslt![indexPath.item] : videoAssestResult![indexPath.item]) as! PHAsset
        
        if segmentedControl.selectedSegmentIndex == 1 {
            retrievePlayerItem(phAsset: selectedAsset)
            videoAsset = selectedAsset
            return
        }
        
        imageManager.requestImageForAsset(selectedAsset,
            targetSize: CGSizeMake(selectedAssetImageSize, selectedAssetImageSize),
            contentMode: .AspectFill,
            options: nil) { (result, info) -> Void in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.assetImageView?.image = result
                    if let imageResult = result {
                        self.displayImage(imageResult)
                    }
                    
                })
        }
    }
}

extension Int {
    var degreesToRadians : CGFloat {
        return CGFloat(self) * CGFloat(M_PI) / 180.0
    }
}

extension NSURL {
    class func thumbNailFromVideoURl(url: NSURL) -> UIImage? {
        
        let asset: AVURLAsset = AVURLAsset(URL: url, options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        
        var cgImage: CGImage?
        do {
            cgImage = try imgGenerator.copyCGImageAtTime(CMTimeMake(0, 600), actualTime: nil)
            let image = UIImage(CGImage: cgImage!)
            return image
        } catch {
            print("Failed to create thumbnail")
        }
        
        return nil
    }
}

extension UIColor {
    
    class func greenAppColor() -> UIColor {
        return UIColor(red: 0.0/255.0, green: 192.0/255.0, blue: 203.0/255.0, alpha: 1.0)
    }
}












