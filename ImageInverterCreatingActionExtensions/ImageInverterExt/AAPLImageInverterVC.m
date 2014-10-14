/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  This view controller is the entry point of the Action extension. It looks for an image from the input items. If it finds an image, it will invert it (flip it vertically) and present it in a UIImageView.
  
 */

#import "AAPLImageInverterVC.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface AAPLImageInverterVC (){

    IBOutlet UIImageView* imageView;
    IBOutlet UIBarButtonItem* cancelButton;
    IBOutlet UIBarButtonItem* doneButton;
    
}

-(IBAction)cancel:(id)sender;
-(IBAction)done:(id)sender;

@end

@implementation AAPLImageInverterVC

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Enable the Cancel button, disable the Done button
    [cancelButton setEnabled:YES];
    [doneButton setEnabled:NO];
    
    // Verify that we have a valid NSExtensionItem
    NSExtensionItem *imageItem = [self.extensionContext.inputItems firstObject];
    if(!imageItem){
        return;
    }
    
    // Verify that we have a valid NSItemProvider
    NSItemProvider *imageItemProvider = [[imageItem attachments] firstObject];
    if(!imageItemProvider){
        return;
    }
    
    // Look for an image inside the NSItemProvider
    if([imageItemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeImage]){
        
        [imageItemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeImage options:nil completionHandler:^(UIImage *image, NSError *error) {
            
            if(image){
                
                // Invert the image, enable the Done button
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    // Invert the image
                    UIImage* invertedImage = [self invertedImage:image];
                    
                    // Set the inverted image in the UIImageView
                    [imageView setImage:invertedImage];
                    [doneButton setEnabled:YES];
                });
                
            }
        }];
        
    }
}

-(UIImage*)invertedImage:(UIImage*)originalImage{
    // Invert the image by applying an affine transformation
    UIGraphicsBeginImageContext(originalImage.size);
    
    // Apply an affine transformation to the original image to generate a vertically flipped image
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGAffineTransform affineTransformationInvert = CGAffineTransformMake(1,0,0,-1,0,originalImage.size.height);
    CGContextConcatCTM(context, affineTransformationInvert);
    [originalImage drawAtPoint:CGPointMake(0, 0)];
    
    UIImage *invertedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return invertedImage;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void)cancel:(id)sender{
    
    // Cancel the request
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:@"ImageInverterErrorDomain" code:0 userInfo:nil]];

}

-(void)done:(id)sender{
    
    // Create the NSExtensionItem and NSItemProvider in which we return the image
    NSExtensionItem* extensionItem = [[NSExtensionItem alloc] init];
    [extensionItem setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Inverted Image"]];
    [extensionItem setAttachments:@[[[NSItemProvider alloc] initWithItem:[imageView image] typeIdentifier:(NSString*)kUTTypeImage]]];
    [self.extensionContext completeRequestReturningItems:@[extensionItem] completionHandler:nil];

}


@end
