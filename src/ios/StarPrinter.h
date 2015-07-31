//UniversalAnalyticsPlugin.h
//Created by Daniel Wilson 2013-09-19

#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>
#import <StarIO/SMPort.h>
#import "MiniPrinterFunctions.h"

@interface StarPrinter : CDVPlugin {
    bool _trackerStarted;
    bool _debugMode;
	NSMutableDictionary *_customDimensions;
}

- (void) PrintSampleReceipt: (CDVInvokedUrlCommand*)command;
- (void) PrintInvoice: (CDVInvokedUrlCommand*)command;
- (NSData *)english3inchSampleReceipt;
- (void)sendCommand:(NSData *)commands
           portName:(NSString *)portName
       portSettings:(NSString *)portSettings
      timeoutMillis:(u_int32_t)timeoutMillis
       errorMessage:(NSMutableString *)message;
- (NSString *) rightPadString:(NSString *)s
                  withPadding:(NSString *)padding
                   withLength:(NSUInteger *)length;
- (NSString *) leftPadString:(NSString *)s
                 withPadding:(NSString *)padding
                  withLength:(int)length;
- (UIImage *)getBlackAndWhiteVersionOfImage:(UIImage *)anImage; 
@end

