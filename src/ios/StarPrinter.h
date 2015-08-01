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

- (void) CheckStatus: (CDVInvokedUrlCommand*)command;
- (void) CheckFirmwareVersion: (CDVInvokedUrlCommand*)command;
- (void) PrintSampleReceipt: (CDVInvokedUrlCommand*)command;
- (void) PrintSignature: (CDVInvokedUrlCommand*)command;

@end

