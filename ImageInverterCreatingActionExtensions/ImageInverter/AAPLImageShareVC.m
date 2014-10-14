/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Presents a UIImageView along with an Action button to share the UIImage contained in the UIImageView.
  
 */

#import "AAPLImageShareVC.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface AAPLImageShareVC (){
    IBOutlet UIImageView* imageView;
}

@end

@implementation AAPLImageShareVC

- (void)viewDidLoad
{
    [super viewDidLoad];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

}

- (IBAction)share:(id)sender {
    
    // Create a UIActivityViewController with our image
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[[imageView image]] applicationActivities:nil];
    
    // Set a completion handler to handle what the UIActivityViewController returns
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError * error){

        if([returnedItems count] > 0){
            
            NSExtensionItem* extensionItem = [returnedItems firstObject];
            NSItemProvider* imageItemProvider = [[extensionItem attachments] firstObject];
            
            if([imageItemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeImage]){
                
                [imageItemProvider loadItemForTypeIdentifier:(NSString *)kUTTypeImage options:nil completionHandler:^(UIImage *item, NSError *error) {
                    
                    if(item && !error){
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [imageView setImage:item];
                        });
                        
                    }
                }];
                
            }
        }
    }];
    [self presentViewController:activityViewController animated:YES completion:nil];
}

@end
