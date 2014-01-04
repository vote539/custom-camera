//
//  CustomCameraViewController.h
//  CustomCamera
//
//  Created by Shane Carr on 1/3/14.
//
//

#import <UIKit/UIKit.h>

// We can't import the CustomCamera class because it would make a circular reference, so "fake" the existence of the class like this:
@class CustomCamera;

@interface CustomCameraViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

// Action method
-(IBAction) takePhotoButtonPressed:(id)sender forEvent:(UIEvent*)event;

// Declare some properties (to be explained soon)
@property (strong, nonatomic) CustomCamera* plugin;
@property (strong, nonatomic) UIImagePickerController* picker;

@end