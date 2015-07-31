//UniversalAnalyticsPlugin.m
//Created by Daniel Wilson 2013-09-19

#import "StarPrinter.h"
#import <sys/time.h>
#import "MiniPrinterFunctions.h"
#import "SigGen.h"
#import "StarBitmap.h"

@implementation StarPrinter

- (void) PrintSampleReceipt: (CDVInvokedUrlCommand*)command
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"You are in PrintSampleReceipt."
                                                    message:@""
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    CDVPluginResult* pluginResult = nil;
    //NSString* accountId = [command.arguments objectAtIndex:0];
    
    
    NSMutableString* message = nil;//[NSMutableString stringWithString:@"Error has Occured"];
    
    
    [MiniPrinterFunctions PrintSampleReceiptWithPortname:@"BT:PRNT Star"
                                            portSettings:@"Portable;escpos"
                                              paperWidth:1
                                            errorMessage:message];
//    [MiniPrinterFunctions CheckStatusWithPortname:@"BT:PRNT Star"
//                                     portSettings:@"Portable;escpos"
//                                    sensorSetting:NoDrawer];

    if (message == nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    }
//    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
     NSLog(@"successfully started GAI tracker");
}
- (NSString *) rightPadString:(NSString *)s withPadding:(NSString *)padding withLength:(NSUInteger *)length {
    
    
    NSString *padded = [s stringByPaddingToLength:*length withString:padding startingAtIndex:0];
    return padded;
}
- (NSString *) leftPadString:(NSString *)s withPadding:(NSString *)padding withLength:(int)length  {
    
    NSUInteger sLength = [s length];
    
    if (sLength > length) {
        return s;
    }
    NSString *padding1 = [@"" stringByPaddingToLength: (length - [s length])
                                          withString: padding
                                     startingAtIndex: 0];
    NSString *padded_string = [padding1 stringByAppendingString: s];
    return padded_string;
//    NSString *padded = [padding stringByAppendingString:s];
//    return [padded substringFromIndex:[padded length] - [padding length]];
}

/**
 *  This function create the sample receipt data (3inch)
 */
- (NSData *)english3inchSampleReceipt:(NSArray *)invoice
                             sig:(NSString *)sig
                         invoiceDetail:(NSString *)invoiceDetail {
    NSMutableData *commands = [NSMutableData data];
    
    NSInteger iCount;
    iCount = 0;
    
    //Get Invoice Detail
    NSData *jsonData = [invoiceDetail dataUsingEncoding:NSUTF8StringEncoding];
    NSError *e;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&e];
    

    NSString *InvoiceNumber;
    InvoiceNumber = [dict objectForKey:@"InvoiceNumber"];
    
    
    NSString *InvoiceDate;
    InvoiceDate = [dict objectForKey:@"InvoiceDate"];
    
    NSString *InvoiceTotal;
    InvoiceTotal = [dict objectForKey:@"InvoiceTotal"];
    
    
    [commands appendBytes:"\x1d\x57\x40\x32"
                   length:sizeof("\x1d\x57\x40\x32") - 1];    // Page Area Setting     <GS> <W> nL nH  (nL = 64, nH = 2)
    
    [commands appendBytes:"\x1b\x61\x01"
                   length:sizeof("\x1b\x61\x01") - 1];    // Center Justification  <ESC> a n       (0 Left, 1 Center, 2 Right)
    
    NSUInteger ninePad;
    ninePad= (NSUInteger)9;
    
    NSUInteger fifteenPad;
    fifteenPad = (NSUInteger)15;
    
    NSUInteger fivePad;
    fivePad = (NSUInteger)5;
    
    NSUInteger sixPad;
    sixPad = (NSUInteger)6;
    
    NSUInteger eightPad;
    eightPad = (NSUInteger)8;
    
    NSUInteger thirteenPad;
    thirteenPad = (NSUInteger)13;
    
    for(NSArray *allProducts in invoice)
    {
        NSDictionary *header = [allProducts objectAtIndex:0];
        
        if(iCount == 0)
        {        [commands appendBytes:"\x1d\x21\x11"
                                length:sizeof("\x1d\x21\x11") - 1];    // Width and Height Character Expansion  <GS>  !  n
            
            //Header
            NSString *aSubValue = [NSString stringWithFormat:@"%@%@%@%@", [header objectForKey:@"LocationName"],@" " , [header objectForKey:@"StoreNumber"],@"\n"];
            aSubValue = [NSString stringWithFormat:@"%@%@%@", aSubValue ,[header objectForKey:@"Street1"],@"\n"];
            aSubValue = [NSString stringWithFormat:@"%@%@%@", aSubValue ,[header objectForKey:@"City"],@", "];
            aSubValue = [NSString stringWithFormat:@"%@%@%@", aSubValue ,[header objectForKey:@"State"],@" "];
            aSubValue = [NSString stringWithFormat:@"%@%@%@", aSubValue ,[header objectForKey:@"Zip"],@"\n\n"];
            [commands appendData:[aSubValue dataUsingEncoding:NSASCIIStringEncoding]];
            
            [commands appendBytes:"\x1d\x21\x00"
                           length:sizeof("\x1d\x21\x00") - 1];    // Cancel Expansion - Reference Star Portable Printer Programming Manual
            [commands appendBytes:"\x1b\x61\x02"
                           length:sizeof("\x1b\x61\x02") - 1];    // Right Alignment
            [commands appendBytes:"\x1b\x45\x01"
                           length:sizeof("\x1b\x45\x01") - 1];    // Set Emphasized Printing ON
            
            InvoiceNumber = [NSString stringWithFormat:@"%@%@%@", @"Invoice Number:", [self leftPadString:InvoiceNumber withPadding:@" " withLength:15 ],  @"\n"];
            
            
            [commands appendData:[InvoiceNumber dataUsingEncoding:NSASCIIStringEncoding]];
            InvoiceDate = [NSString stringWithFormat:@"%@%@%@",@"Invoice Date:", [self leftPadString:InvoiceDate withPadding:@" " withLength:15 ], @"\n\n\n"];
            [commands appendData:[InvoiceDate dataUsingEncoding:NSASCIIStringEncoding]];
        }
        iCount++;
        
        [commands appendBytes:"\x1b\x61\x00"
                       length:sizeof("\x1b\x61\x00") - 1];    // Left Alignment
        [commands appendBytes:"\x1b\x45\x01"
                       length:sizeof("\x1b\x45\x01") - 1];    // Set Emphasized Printing ON
        
        [commands appendBytes:"\x1d\x21\x11"
                       length:sizeof("\x1d\x21\x11") - 1];    // Width and Height Character Expansion  <GS>  !  n
        
        
        
        //Product
        NSString *ProductName = [NSString stringWithFormat:@"%@%@", [header objectForKey:@"ProductName"],@"\n"];
        [commands appendData:[ProductName dataUsingEncoding:NSASCIIStringEncoding]];
        
        [commands appendBytes:"\x1b\x45\x00"
                       length:sizeof("\x1b\x45\x00") - 1];    // Set Emphasized Printing OFF (same command as on)

        [commands appendBytes:"\x1d\x21\x00"
                       length:sizeof("\x1d\x21\x00") - 1];    // Cancel Expansion - Reference Star Portable Printer Programming Manual
        [commands appendBytes:"\x1b\x61\x01"
                       length:sizeof("\x1b\x61\x01") - 1];    // Center Justification  <ESC> a n       (0 Left, 1 Center, 2 Right)
        
        //Information Header

        
        NSString *Date = [@"Date" stringByPaddingToLength:9 withString:@" " startingAtIndex:0];
        NSString *Edition = [@"Edition" stringByPaddingToLength:15 withString:@" " startingAtIndex:0];
        NSString *In = [self leftPadString:@"In" withPadding:@" "  withLength:5];
        NSString *Out = [self leftPadString:@"Out" withPadding:@" "  withLength:5];
        NSString *Price = [self leftPadString:@"Price" withPadding:@" "  withLength:6];
        NSString *Total = [self leftPadString:@"Total" withPadding:@" "  withLength:8];
        
        NSString *InfoHeader = [NSString stringWithFormat:@"%@%@%@%@%@%@%@",Date,Edition,In,Out,Price,Total,@"\n"];
        
        
        [commands appendData:[InfoHeader dataUsingEncoding:NSASCIIStringEncoding]];
        
        for(NSDictionary *eachInvoice in allProducts)  {
            //Delivery Data
            [commands appendData:[[self rightPadString:[eachInvoice objectForKey:@"10"] withPadding:@" "  withLength:&ninePad] dataUsingEncoding:NSASCIIStringEncoding]];
            [commands appendData:[[self rightPadString:[eachInvoice objectForKey:@"9"] withPadding:@" "  withLength:&fifteenPad] dataUsingEncoding:NSASCIIStringEncoding]];
            NSString *QuantityIn = [NSString stringWithFormat:@"%@", [eachInvoice objectForKey:@"QuantityIn"]];
            QuantityIn = [self leftPadString:QuantityIn withPadding:@" "  withLength:5];
            [commands appendData:[QuantityIn dataUsingEncoding:NSASCIIStringEncoding]];
            
            NSString *QuantityOut = [NSString stringWithFormat:@"%@", [eachInvoice objectForKey:@"QuantityOut"]];
            QuantityOut = [self leftPadString:QuantityOut withPadding:@" "  withLength:5];
            [commands appendData:[QuantityOut dataUsingEncoding:NSASCIIStringEncoding]];
            
            [commands appendData:[[self leftPadString:[eachInvoice objectForKey:@"12"] withPadding:@" "  withLength:6] dataUsingEncoding:NSASCIIStringEncoding]];
            [commands appendData:[[self leftPadString:[eachInvoice objectForKey:@"15"] withPadding:@" "  withLength:8] dataUsingEncoding:NSASCIIStringEncoding]];
            [commands appendData:[[NSString stringWithFormat:@"%@", @"\n"] dataUsingEncoding:NSASCIIStringEncoding]];
        }
        
        [commands appendData:[@"------------------------------------------------\n" dataUsingEncoding:NSASCIIStringEncoding]];
        [commands appendBytes:"\x1b\x45\x01"
                       length:sizeof("\x1b\x45\x01") - 1];    // Set Emphasized Printing ON

        [commands appendBytes:"\x1d\x21\x11"
                       length:sizeof("\x1d\x21\x11") - 1];    // Width and Height Character Expansion  <GS>  !  n
        
                [commands appendData:[[NSString stringWithFormat:@"%@%@%@", [self rightPadString:@"Total" withPadding:@" " withLength:&eightPad] ,
                                       [self leftPadString:[NSString stringWithFormat:@"%@%@" , @"$", [header objectForKey:@"16"]] withPadding:@" "  withLength:16]
                                        ,@"\n\n\n\n"] dataUsingEncoding:NSASCIIStringEncoding]];
        
        [commands appendBytes:"\x1b\x45\x00"
                       length:sizeof("\x1b\x45\x00") - 1];    // Set Emphasized Printing OFF (same command as on)
        
        [commands appendBytes:"\x1d\x21\x00"
                       length:sizeof("\x1d\x21\x00") - 1];    // Cancel Expansion - Reference Star Portable Printer Programming Manual

    }
    
    
    //Invoice Total and Bitmap
    
    if(iCount > 1){
        [commands appendData:[@"------------------------------------------------\n" dataUsingEncoding:NSASCIIStringEncoding]];
        [commands appendBytes:"\x1b\x45\x01"
                       length:sizeof("\x1b\x45\x01") - 1];    // Set Emphasized Printing ON
        
        [commands appendBytes:"\x1d\x21\x11"
                       length:sizeof("\x1d\x21\x11") - 1];    // Width and Height Character Expansion  <GS>  !  n
        [commands appendData:[[NSString stringWithFormat:@"%@%@%@", [self rightPadString:@"Invoice Total" withPadding:@" " withLength:&thirteenPad] , [self leftPadString:[NSString stringWithFormat:@"%@%@" , @"$", InvoiceTotal] withPadding:@" "  withLength:11] ,@"\n"] dataUsingEncoding:NSASCIIStringEncoding]];
        [commands appendBytes:"\x1b\x45\x00"
                       length:sizeof("\x1b\x45\x00") - 1];    // Set Emphasized Printing OFF (same command as on)
        
        [commands appendBytes:"\x1d\x21\x00"
                       length:sizeof("\x1d\x21\x00") - 1];    // Cancel Expansion - Reference Star Portable Printer Programming Manual
    }
    [commands appendBytes:"\x1b\x61\x01"
                   length:sizeof("\x1b\x61\x01") - 1];    // Center Justification  <ESC> a n       (0 Left, 1 Center, 2 Right)

    [commands appendData:[@"\n\n------------------Sign Here---------------------\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    
    
    //Print Signature
    NSData *jsonSig = [sig dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *sifDitionary = [NSJSONSerialization JSONObjectWithData:jsonSig options:0 error:nil];
    NSLog(@"%@",sig);
    
    NSArray *objectArray = sifDitionary[@"lines"];
    
    UIImage *signature = [SigGen drawSignatureBMP:objectArray];
    
//    signature = [self getBlackAndWhiteVersionOfImage:signature];
    
    StarBitmap *starbitmap = [[StarBitmap alloc] initWithUIImage:signature :576 :false];
    NSData *invoiceSignature = [starbitmap getImageMiniDataForPrinting:true pageModeEnable:false];
    [commands appendData:invoiceSignature];
    
    [commands appendBytes:"\x1b\x61\x01"
                   length:sizeof("\x1b\x61\x01") - 1];    // Center Justification  <ESC> a n       (0 Left, 1 Center, 2 Right)

    
    [commands appendData:[@"------------------------------------------------\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [commands appendData:[@"Thank you for your business!\n\n\n\n\n\n\n\n\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    
    return commands;
}
- (UIImage *)getBlackAndWhiteVersionOfImage:(UIImage *)anImage {
    UIImage *newImage;
    
    if (anImage) {
        CGColorSpaceRef colorSapce = CGColorSpaceCreateDeviceGray();
        CGContextRef context = CGBitmapContextCreate(nil, anImage.size.width * anImage.scale, anImage.size.height * anImage.scale, 8, anImage.size.width * anImage.scale, colorSapce, kCGImageAlphaNone);
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        CGContextSetShouldAntialias(context, NO);
        CGContextDrawImage(context, CGRectMake(0, 0, anImage.size.width, anImage.size.height), [anImage CGImage]);
        
        CGImageRef bwImage = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        CGColorSpaceRelease(colorSapce);
        
        UIImage *resultImage = [UIImage imageWithCGImage:bwImage];
        CGImageRelease(bwImage);
        
        UIGraphicsBeginImageContextWithOptions(anImage.size, NO, anImage.scale);
        [resultImage drawInRect:CGRectMake(0.0, 0.0, anImage.size.width, anImage.size.height)];
        newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    return newImage;
}
- (void) PrintInvoice: (CDVInvokedUrlCommand*)command
{
    NSData *commands = nil;
    
    //0 = "invoice": invoice,
    //1 = "sig": sig,
    //2 = "invoiceDetail": invoiceDetail
    
    NSArray *invoice = [command.arguments objectAtIndex:0];
    NSString* sig = [command.arguments objectAtIndex:1];
    NSString* invoiceDetail = [command.arguments objectAtIndex:2];

    
    commands = [self english3inchSampleReceipt:invoice sig:sig invoiceDetail:invoiceDetail];
    
    
    CDVPluginResult* pluginResult = nil;    
    
    NSMutableString* message = [NSMutableString stringWithString:@""];
    
    
    [self sendCommand:commands portName:@"BT:PRNT Star" portSettings:@"Portable;escpos" timeoutMillis:10000 errorMessage:message];
    
//    
//    NSData *jsonSig = [sig dataUsingEncoding:NSUTF8StringEncoding];
//    NSDictionary *sifDitionary = [NSJSONSerialization JSONObjectWithData:jsonSig options:0 error:nil];
//    NSLog(@"%@",sig);
//    
//    NSArray *objectArray = sifDitionary[@"lines"];
//
//    
//    UIImage *signature2 = [SigGen drawSignatureBMP:objectArray];
//    
//    
//    [MiniPrinterFunctions PrintBitmapWithPortName:@"BT:PRNT Star"
//                                     portSettings:@"Portable;escpos"
//                                      imageSource:signature2
//                                     printerWidth:576
//                                compressionEnable:true
//                                   pageModeEnable:false];
    
    
    
    
    
    NSUInteger length = [message length];
    
    if (length == 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    NSLog(@"successfully started GAI tracker");
}

- (void)sendCommand:(NSData *)commands
           portName:(NSString *)portName
       portSettings:(NSString *)portSettings
      timeoutMillis:(u_int32_t)timeoutMillis
       errorMessage:(NSMutableString *)message
{
    unsigned char *commandsToSendToPrinter = (unsigned char *)malloc(commands.length);
    [commands getBytes:commandsToSendToPrinter length:commands.length];
    int commandSize = (int)[commands length];
    
    SMPort *starPort = nil;
    @try
    {
        starPort = [SMPort getPort:portName :portSettings :timeoutMillis];
        if (starPort == nil) {
            [message appendString:@"Fail to Open Printer Port.\nPrinter might be offline."];
            return;
        }
        
        struct timeval endTime;
        gettimeofday(&endTime, NULL);
        endTime.tv_sec += 60;
        
        StarPrinterStatus_2 status;
        [starPort beginCheckedBlock:&status :2];
        
        if (status.offline == SM_TRUE) {
            [message appendString:@"Printer is offline"];
            return;
        }
        
        int totalAmountWritten = 0;
        while (totalAmountWritten < commandSize) {
            int remaining = commandSize - totalAmountWritten;
            
            int amountWritten = [starPort writePort:commandsToSendToPrinter :totalAmountWritten :remaining];
            totalAmountWritten += amountWritten;
            
            struct timeval now;
            gettimeofday(&now, NULL);
            if (now.tv_sec > endTime.tv_sec) {
                break;
            }
        }
        
        starPort.endCheckedBlockTimeoutMillis = 40000;
        [starPort endCheckedBlock:&status :2];
        if (status.offline == SM_TRUE) {
            [message appendString:@"An error has occurred during printing."];
            return;
        }
        
        if (totalAmountWritten < commandSize) {
            [message appendString:@"Write port timed out"];
            return;
        }
    }
    @catch (PortException *exception)
    {
        [message appendString:@"Write port timed out"];
        return;
    }
    @finally
    {
        [SMPort releasePort:starPort];
        free(commandsToSendToPrinter);
    }
}


@end
