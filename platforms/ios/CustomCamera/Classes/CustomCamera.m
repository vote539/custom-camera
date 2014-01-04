//
//  CustomCamera.m
//  CustomCamera
//
//  Created by Shane Carr on 1/3/14.
//
//

#import "CustomCamera.h"

@implementation CustomCamera

// Cordova command method
-(void) openCamera:(CDVInvokedUrlCommand *)command {
    
	// Set the hasPendingOperation field to prevent the webview from crashing
	self.hasPendingOperation = YES;
    
	// Save the CDVInvokedUrlCommand as a property.  We will need it later.
	self.latestCommand = command;
    
	// Make the overlay view controller.
	self.overlay = [[CustomCameraViewController alloc] initWithNibName:@"CustomCameraViewController" bundle:nil];
	self.overlay.plugin = self;
    
	// Display the view.  This will "slide up" a modal view from the bottom of the screen.
	[self.viewController presentViewController:self.overlay.picker animated:YES completion:nil];
}

// Method called by the overlay when the image is ready to be sent back to the web view
-(void) capturedImageWithPath:(NSString*)imagePath {
	[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:imagePath] callbackId:self.latestCommand.callbackId];
    
	// Unset the self.hasPendingOperation property
	self.hasPendingOperation = NO;
    
    // Hide the picker view
    [self.viewController dismissModalViewControllerAnimated:YES];
}

@end