//
//  ViewController.swift
//  SSPhotoLibrary
//
//  Created by Steeven Sylveus on 6/7/16.
//  Copyright © 2016 Steeven Sylveus. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {

    @IBOutlet weak var selectedImageView: UIImageView!
    
    let ssPhotoLibraryName = "SSPhotoLibaray";
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    @IBAction func choosePhoto(sender: AnyObject) {
        let ssPhotoStoryboard = UIStoryboard(name: ssPhotoLibraryName, bundle: nil)
        let ssPhotoVC: SSPhotoLibaray = ssPhotoStoryboard.instantiateViewControllerWithIdentifier(ssPhotoLibraryName) as! SSPhotoLibaray
        ssPhotoVC.hideVideos = false
        ssPhotoVC.delegate = self
        ssPhotoVC.hideVideos = true
        presentViewController(ssPhotoVC, animated: true, completion: nil)
    }
}

extension ViewController: SSPhotoLibraryDelegate {
    
    func didFinishPickingImageAsset(asset: PHAsset, withCroppedImage image: UIImage) {
        selectedImageView.image = image
    }
    
    func didFinishPickingVidoAsset(asset: AVAsset, withVideoUrl url: NSURL, withVideoImage image: UIImage) {
        
    }
}

