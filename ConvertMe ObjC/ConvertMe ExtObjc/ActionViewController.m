//
//  ActionViewController.m
//  ConvertMe ExtObjc
//
//  Created by Olga Dalton on 28/08/14.
//  Copyright (c) 2014 swiftiostutorials.com. All rights reserved.
//

#import "ActionViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface ActionViewController ()

@property (nonatomic, strong) NSString *jsString;
@property (nonatomic) double feetsInMeter;
@property (nonatomic) double metersInFoot;

- (void) performConversionWithRegexPattern: (NSString *) regexPattern replacementString: (NSString *) replacement andMultiplier: (double) multiplier;

- (void) finalizeReplace;

@end

@implementation ActionViewController
@synthesize jsString, feetsInMeter, metersInFoot;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    feetsInMeter = 3.2808399;
    metersInFoot = 0.3048;
    
    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in item.attachments) {
            if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypePropertyList]) {
                
                __weak ActionViewController *sself = self;
                
                [itemProvider loadItemForTypeIdentifier: (NSString *) kUTTypePropertyList options: 0 completionHandler: ^(id<NSSecureCoding> item, NSError *error) {
                    
                      if (item != nil) {
                        
                          NSDictionary *resultDict = (NSDictionary *) item;
                          
                          sself.jsString = resultDict[NSExtensionJavaScriptPreprocessingResultsKey][@"content"];
                          
                      }
                    
                }];
                
            }
        }
    }
}

- (void) performConversionWithRegexPattern: (NSString *) regexPattern replacementString: (NSString *) replacementString andMultiplier: (double) multiplier
{
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern: regexPattern options:NSRegularExpressionCaseInsensitive error: nil];
    
    NSArray *matches = [regex matchesInString: self.jsString options: 0 range: NSMakeRange(0, self.jsString.length)];
    
    for (NSTextCheckingResult *result in [matches reverseObjectEnumerator]) {
    
        NSString *match = [regex replacementStringForResult: result inString: self.jsString offset: 0 template: @"$0"];
        
        double conversionResult = [match doubleValue] * multiplier;
        NSString *replacement = [[NSString alloc] initWithFormat: replacementString, conversionResult];
        
        self.jsString = [self.jsString stringByReplacingOccurrencesOfString: match withString: replacement];
    }
}

- (void) finalizeReplace
{
    NSExtensionItem *extensionItem = [[NSExtensionItem alloc] init];
    
    NSDictionary *item = @{@"NSExtensionJavaScriptFinalizeArgumentKey": @{@"content": self.jsString}};
    
    NSItemProvider *itemProvider = [[NSItemProvider alloc] initWithItem: item typeIdentifier: (NSString *) kUTTypePropertyList];
    extensionItem.attachments = @[itemProvider];
    
    [self.extensionContext completeRequestReturningItems: @[extensionItem] completionHandler: nil];
}

- (IBAction) convertMetersToFt:(id)sender
{
    [self performConversionWithRegexPattern: @"(([-+]?[0-9]*\\.?[0-9]+)\\s*(m))"
                          replacementString: @"%.2f ft"
                              andMultiplier: self.feetsInMeter];
    [self finalizeReplace];
}

- (IBAction) convertFtToMeters:(id)sender
{
    [self performConversionWithRegexPattern: @"(([-+]?[0-9]*\\.?[0-9]+)\\s*(ft))"
                          replacementString: @"%.2f m"
                              andMultiplier: self.metersInFoot];
    
    [self finalizeReplace];
}

- (IBAction) cancel:(id)sender
{
    [self finalizeReplace];
}

@end
