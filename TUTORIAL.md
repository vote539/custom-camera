# Writing a Custom Camera Plugin for PhoneGap

Original text at http://codrspace.com/vote539/writing-a-custom-camera-plugin-for-phonegap/

[PhoneGap](http://phonegap.com/) (the brand name of [Apache Cordova](http://cordova.apache.org/)) is a great tool for writing cross platform mobile applications.  With JavaScript and rendering engines getting faster by the minute, we're quickly approaching the time when many apps can be written exclusively on the web platform without needing to dive into Objective-C and Java for iOS and Android.

Like all great things in life, though, PhoneGap has its limitations.  For example, the abstraction away from Cocoa Touch means that the UI of your application is not automatically updated with new versions of iOS.  But perhaps the most clearly defined limitation is the integration with native components.  PhoneGap does a good job of abstracting things like [contacts](http://docs.phonegap.com/en/edge/cordova_contacts_contacts.md.html) and the [accelerometer](http://docs.phonegap.com/en/edge/cordova_accelerometer_accelerometer.md.html), but it struggles with native components that require more than just an API.

In this blog post, I will dive into one of these native components: the camera.  I will explain the limitations behind PhoneGap's out-of-the-box implementation of the camera, the steps you need to take to implement a custom camera overlay in iOS, and some tips and tricks along the way.  I assume that you are competent in JavaScript and Objective-C, and that you are developing on a Mac with Xcode installed.  Since the iOS simulator does not have a camera at the time of writing, you will also need a physical iOS device for testing.  If at any time you get lost or your code doesn't work, you can refer to [a working copy of CustomCamera on GitHub](https://github.com/vote539/custom-camera).  Let's get started!

## The Default PhoneGap Camera

The [default PhoneGap camera plugin](http://docs.phonegap.com/en/edge/cordova_camera_camera.md.html) has a clean JavaScript interface.  From a developer's point of view, capturing a photo is as easy as one command:

```bash
$ phonegap local plugin add org.apache.cordova.camera
```

…followed by a few lines of code:

```javascript
navigator.camera.getPicture(function(imagePath){
	document.getElementById("photoImg").setAttribute("src", imagePath);
}, function(){
	alert("Photo cancelled");
}, {
	destinationType: navigator.camera.DestinationType.FILE_URI
});
```

However, from the end user's point of view, things are not quite as slick.  On iOS, a modal opens with the same camera overlay as the native UI.  They can choose an image from their preexisting photo albums, or they can snap a new one.  They are then brought to a screen where they can preview the photo and choose to retake it.  Finally, when they submit the image, the modal closes and the JavaScript callback is evaluated.

![default-phonegap-camera.jpg](/site_media/media/eda6646a74e81.jpg)

This is fine for an app where the camera is not a core feature, but for apps where the user spends a significant amount of time taking photos, the default PhoneGap camera might not give a good user experience (UX).

## Writing the PhoneGap Plugin

We can make a custom user experience by writing a [PhoneGap plugin](http://docs.phonegap.com/en/edge/guide_hybrid_plugins_index.md.html).  The folks at Apache have improved the plugin API and its documentation substantially in the past few months, but there is still a definite learning curve.

I'm going to do my best to walk you through the process of creating a camera plugin for iOS.

### Step 1: Create an empty PhoneGap project

The first thing we need to do is to create a new empty PhoneGap project and add iOS support.  If you have the [PhoneGap Command Line Interface](http://docs.phonegap.com/en/edge/guide_cli_index.md.html) installed, you just need to run:

```bash
# NOTE: Change com.example.custom-camera to something else unique to your organization.
$ phonegap create custom_camera com.example.custom-camera CustomCamera
$ cd custom_camera
$ phonegap local build ios
```

The last line creates the iOS project directory at `custom_camera/platforms/ios`.

### Step 2: Write the JavaScript bindings

It will make our lives easier if we write the JavaScript bindings for our plugin right up front.  Make a new JavaScript file at `custom_camera/www/js/custom_camera.js`.  Put in the following code:

```javascript
var CustomCamera = {
	getPicture: function(success, failure){
		cordova.exec(success, failure, "CustomCamera", "openCamera", []);
	}
};
```

`cordova.exec` is an automagic function that lets us call an Objective-C method from JavaScript.  In this case, it will create an instance of `CustomCamera` and call `openCamera` on that instance.  We will write the `CustomCamera` class in Objective-C in the next step.

Notice how we made our API very close to PhoneGap's camera API.  This is optional.  At the end of the day everything boils down to `cordova.exec`.

Let's also create a button that we can tap to run the above function.  Modify `custom_camera/www/index.html` and add the following inside the `div.app` tag:

```html
<button id="openCustomCameraBtn">Open Custom Camera</button>
<img id="photoImg" style="position: fixed; top: 0; width: 50%; left: 25%;" />
<script src="js/custom_camera.js"></script>
<script>
document.getElementById("openCustomCameraBtn").addEventListener("click", function(){
	CustomCamera.getPicture(function(imagePath){
		document.getElementById("photoImg").setAttribute("src", imagePath);
	}, function(){
		alert("Photo cancelled");
	});
}, false);
</script>
```

Finally, don't forget to tell PhoneGap to copy the new files into our iOS project directory.

```bash
$ phonegap local build ios
```

### Step 3: Set up the Xcode Project

If you run the above app on your iOS device, you will get an error telling you that the `CustomCamera` class is not defined.  This is where we get to start diving into the Objective-C.

Open up the Xcode project located at `custom_camera/platforms/ios/CustomCamera.xcodeproj`.  Press ⌘N, make a new Objective-C class for Cocoa Touch, name the class `CustomCamera`, and (this is important!) inherit from `CDVPlugin`.  Save it in the Classes folder and the Classes group.

In the previous step, we told our JavaScript to call the `openCamera` method on an instance the `CustomCamera` class.  We need to declare this method.  Make your interface in `CustomCamera.h` look like this:

```objectivec
// Note that Xcode gets this line wrong.  You need to change "Cordova.h" to "CDV.h" as shown below.
#import <Cordova/CDV.h>

// Import the CustomCameraViewController class
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
```

And wait, what the heck is `CustomCameraViewController`?  It's the class that will handle the UI side of the plugin.  Cordova will instantiate an instance of `CustomCamera`, which in turn will instantiate an instance of `CustomCameraViewController` as we will see later.

Press ⌘N again, make another new Objective-C class for Cocoa Touch, name it `CustomCameraViewController`, but this time inherit from `UIViewController`.  I recommend creating a XIB file.  Save it in the Classes folder.

The interface in `CustomCameraViewController.h` should look something like this:

```objectivec
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
```

Now we need to make the button that, when tapped, calls the `takePhotoButtonPressed` method.  To do this, open the XIB file with `CustomCameraViewController.h` still open, make a button on the screen, and Control-Drag the button from the XIB file onto the method in the header file.

![xcode-xib-connection.jpg](/site_media/media/36c2142a74ec1.jpg)

Gotta say it's a decent GUI that Apple put together!

We also need to add code to `custom_camera/platforms/ios/config.xml` in order to make PhoneGap see our plugin.  Add the following lines somewhere inside the `widget` tag:

```xml
    <feature name="CustomCamera">
        <param name="ios-package" value="CustomCamera" />
    </feature>
```

With the header files and XIB out of the way, we need to dive into the guts of the Objective-C.

### Step 4: Write the hard core Objective-C

The primary API for interacting with the camera in iOS is the [UIImagePickerController](https://developer.apple.com/library/ios/documentation/uikit/reference/UIImagePickerController_Class/UIImagePickerController/UIImagePickerController.html).  We will be instantiating an instance of UIImagePickerController, configuring it to fill the whole screen, and opening it as a modal in front of the web view.  When UIPickerController tells us that an image has been captured, we will save it as a JPEG file, tell JavaScript the file name, and close the camera modal.  While the details of UIImagePickerController are beyond the scope of this blog post, it should be relatively straightforward to follow along with the code.

Let's start by writing the implementation for our CustomCameraViewController class, in `CustomCameraViewController.m`.  Please read along with the comments.

```objectivec
#import "CustomCamera.h"
#import "CustomCameraViewController.h"

@implementation CustomCameraViewController

// Entry point method
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
		// Instantiate the UIImagePickerController instance
		self.picker = [[UIImagePickerController alloc] init];
	
		// Configure the UIImagePickerController instance
		self.picker.sourceType = UIImagePickerControllerSourceTypeCamera;
		self.picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
		self.picker.cameraDevice = UIImagePickerControllerCameraDeviceRear;
		self.picker.showsCameraControls = NO;
	
		// Make us the delegate for the UIImagePickerController
		self.picker.delegate = self;
	
		// Set the frames to be full screen
		CGRect screenFrame = [[UIScreen mainScreen] bounds];
		self.view.frame = screenFrame;
		self.picker.view.frame = screenFrame;
	
		// Set this VC's view as the overlay view for the UIImagePickerController
		self.picker.cameraOverlayView = self.view;
	}
	return self;
}

// Action method.  This is like an event callback in JavaScript.
-(IBAction) takePhotoButtonPressed:(id)sender forEvent:(UIEvent*)event {
	// Call the takePicture method on the UIImagePickerController to capture the image.
	[self.picker takePicture];
}

// Delegate method.  UIImagePickerController will call this method as soon as the image captured above is ready to be processed.  This is also like an event callback in JavaScript.
-(void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {

	// Get a reference to the captured image
	UIImage* image = [info objectForKey:UIImagePickerControllerOriginalImage];

	// Get a file path to save the JPEG
	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString* documentsDirectory = [paths objectAtIndex:0];
	NSString* filename = @"test.jpg";
	NSString* imagePath = [documentsDirectory stringByAppendingPathComponent:filename];

	// Get the image data (blocking; around 1 second)
	NSData* imageData = UIImageJPEGRepresentation(image, 0.5);

	// Write the data to the file
	[imageData writeToFile:imagePath atomically:YES];

	// Tell the plugin class that we're finished processing the image
	[self.plugin capturedImageWithPath:imagePath];
}

@end
```

Now let's write the implementation for the CustomCamera class, in `CustomCamera.m`.

```objectivec
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
```

Of special note is the `hasPendingOperation` property on the CDVPlugin.  This is an undocumented property that, when true, prevents the web view from being released from memory (garbage collected) while the camera view is open.  If the web view were to be released from memory, bad things would happen: the app would essentially restart when the camera view closed, and the image data would never reach JavaScript.

### Step 5: Test drive

Phew, that was a lot of Objective-C!  But does it work?

Hook up your iOS device to your computer.  If you haven't yet set up a provisioning profile, do so now.  (For more information on connecting your device to Xcode, ask Google.)  Build and run the app on your device from within Xcode.  Tap the button to open the camera, then tap the button to snap the photo.  The camera overlay should close, and you should see your image within the WebView!

![custom-camera-demo.jpg](/site_media/media/6c3a7fa474fe1.jpg)

The UI could obviously use some improvement, but the guts of the plugin are all there now.

## Bundling the PhoneGap Plugin

In a crunch, you could stop right here and write the rest of your PhoneGap code inside your CustomCamera project.  But the better practice is to give our plugin some *metadata* that we can use to include it in whichever project we want with a click PhoneGap command.

### Step 6: Write plugin.xml

The metadata for PhoneGap plugins is stored in *plugin.xml* at the root of the project directory.  Make `custom_camera/plugin.xml` with the following markup.  More detail can be found [in the PhoneGap docs](http://docs.phonegap.com/en/edge/plugin_ref_spec.md.html).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plugin xmlns="http://apache.org/cordova/ns/plugins/1.0"
	xmlns:android="http://schemas.android.com/apk/res/android"
	xmlns:rim="http://www.blackberry.com/ns/widgets"
	id="com.example.custom-camera"
	version="0.0.1">

<name>Shopeel Camera</name>
<description>PhoneGap plugin to support a custom camera overlay</description>
<author>Shane Carr and others</author>

<info>
	This plugin was written with the tutorial found at:
	http://codrspace.com/vote539/writing-a-custom-camera-plugin-for-phonegap/
</info>

<js-module src="www/js/custom_camera.js" name="CustomCamera">
	<clobbers target="navigator.CustomCamera" />
</js-module>

<engines>
	<engine name="cordova" version=">=3.1.0" />
</engines>

<platform name="ios">

	<!-- config file -->
	<config-file target="config.xml" parent="/*">
		<feature name="CustomCamera">
			<param name="ios-package" value="CustomCamera" />
		</feature>
	</config-file>

	<!-- core CustomCamera header and source files -->
	<header-file src="platforms/ios/CustomCamera/Classes/CustomCamera.h" />
	<header-file src="platforms/ios/CustomCamera/Classes/CustomCameraViewController.h" />
	<source-file src="platforms/ios/CustomCamera/Classes/CustomCamera.m" />
	<source-file src="platforms/ios/CustomCamera/Classes/CustomCameraViewController.m" />
	<resource-file src="platforms/ios/CustomCamera/Classes/CustomCameraViewController.xib" />

</platform>

</plugin>
```

Customize `plugin.xml` with your plugin details, file names, and so on.

### Step 7: Specify the JavaScript binding

PhoneGap plugins treat the JavaScript file we made like a *module*.  This means that `custom_camera.js` will be evaluated in a sandbox, and we need to specifically expose properties in order for us to use them.

Take note of the following lines in `plugin.xml`:

```xml
<js-module src="www/js/custom_camera.js" name="CustomCamera">
	<clobbers target="navigator.CustomCamera" />
</js-module>
```

What this means in English is "include *custom_camera.js* and bind its `module.exports` to `navigator.CustomCamera`".  If you've used Node.JS, you are probably familiar with `module.exports`.  All we need to do is to add the following line to the bottom of `custom_camera.js`:

```javascript
module.exports = CustomCamera;
```

Now, in applications in which we include our plugin, we can open the custom camera view with `navigator.CustomCamera.getPicture()`.

### Step 8: Deploy the plugin

We are finally ready to include our plugin in our real PhoneGap project!

Installing the default PhoneGap camera was as easy as:

```bash
$ phonegap local plugin add org.apache.cordova.camera
```

Guess what: our own custom camera plugin ain't much harder to install!

```bash
$ phonegap local plugin add /path/to/custom_camera
```

You can also give `phonegap local plugin add` a path to your Git repo.

```bash
$ phonegap local plugin add https://github.com/vote539/custom-camera.git
```

## Conclusion

We now have a very basic, working PhoneGap plugin for iOS!

The next steps would include:

 1. Add support for Android, Blackberry, Windows Phone, and all other targeted platforms.  You would first need to add said platform to your PhoneGap project, then you would need to refer to the documentation for PhoneGap and your desired platform about how to implement a camera.  Don't forget to modify `plugin.xml` once you're ready!
 2. [Package your plugin for the community](http://docs.phonegap.com/en/edge/guide_hybrid_plugins_index.md.html#Plugin%20Development%20Guide_publishing_plugins).  This might be as easy as `plugman publish /path/to/custom_camera`.  Before you do this, make sure that you use a real reverse URL identifier for your plugin, rather than *com.example.xyz*.

If this tutorial helped you, let me know by posting a comment below!