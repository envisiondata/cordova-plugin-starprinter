//UniversalAnalyticsPlugin.m
//Created by Daniel Wilson 2013-09-19

#import "StarPrinter.h"
#import <sys/time.h>
#import "MiniPrinterFunctions.h"
#import "SigGen.h"
#import "StarBitmap.h"

@implementation StarPrinter

- (void) CheckStatus: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    
    [MiniPrinterFunctions CheckStatusWithPortname:@"BT:PRNT Star"
                                     portSettings:@"Portable;escpos"
                                    sensorSetting:0];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];}

- (void) CheckFirmwareVersion: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;

    
    [MiniPrinterFunctions showFirmwareInformation:@"BT:PRNT Star"
                                            portSettings:@"Portable;escpos"];
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];}

- (void) PrintSampleReceipt: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    NSMutableString* message = [NSMutableString stringWithString:@""];
    
    
    [MiniPrinterFunctions PrintSampleReceiptWithPortname:@"BT:PRNT Star"
                                            portSettings:@"Portable;escpos"
                                              paperWidth:1
                                            errorMessage:message];
    NSUInteger length = [message length];
    
    if (length == 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) PrintSignature: (CDVInvokedUrlCommand*)command
{
    NSMutableData *commands = [NSMutableData data];
    NSString* sig = [command.arguments objectAtIndex:0];
    CDVPluginResult* pluginResult = nil;
    
    NSMutableString* message = [NSMutableString stringWithString:@""];
    
    
    //Print Signature
    NSData *jsonSig = [sig dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *sifDitionary = [NSJSONSerialization JSONObjectWithData:jsonSig options:0 error:nil];
    NSLog(@"%@",sig);
    
    NSArray *objectArray = sifDitionary[@"lines"];
    
    UIImage *signature = [SigGen drawSignatureBMP:objectArray];
    
    
    StarBitmap *starbitmap = [[StarBitmap alloc] initWithUIImage:signature :576 :false];
    NSData *invoiceSignature = [starbitmap getImageMiniDataForPrinting:true pageModeEnable:false];
    [commands appendData:invoiceSignature];
    
    
    [MiniPrinterFunctions sendCommand:commands portName:@"BT:PRNT Star" portSettings:@"Portable;escpos" timeoutMillis:10000 errorMessage:message];
    

    NSUInteger length = [message length];
    
    if (length == 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
