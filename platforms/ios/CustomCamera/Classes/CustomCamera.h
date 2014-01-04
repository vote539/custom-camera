//
//  CustomCamera.h
//  CustomCamera
//
//  Created by Shane Carr on 1/3/14.
//
//

#import <Cordova/CDV.h>

#import "CustomCameraViewController.h"

@interface CustomCamera : CDVPlugin

// Cordova command method
-(void) openCamera:(CDVInvokedUrlCommand*)command;

// Create and override some properties and methods (these will be explained later)
-(void) capturedImageWithPath:(NSString*)imagePath;
@property (strong, nonatomic) CustomCameraViewController* overlay;
@property (strong, nonatomic) CDVInvokedUrlCommand* latestCommand;
@property (readwrite, assign) BOOL hasPendingOperation;

@end