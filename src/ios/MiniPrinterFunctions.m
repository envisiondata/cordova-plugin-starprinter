//
//  MiniPrinterFunctions.m
//  IOS_SDK
//
//  Created by Tzvi on 8/2/11.
//  Copyright 2011 - 2013 STAR MICRONICS CO., LTD. All rights reserved.
//

#import "MiniPrinterFunctions.h"
#import "StarBitmap.h"
#import <sys/time.h>


@implementation MiniPrinterFunctions

/*!
 *  This function shows the printer firmware information
 *
 *  @param  portName        Port name to use for communication
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 */
+ (void)showFirmwareInformation:(NSString *)portName portSettings:(NSString *)portSettings {
    SMPort *starPort = nil;
    NSDictionary *dict = nil;
    
    @try {
        starPort = [SMPort getPort:portName :portSettings :10000];
        if (starPort == nil) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Fail to Open Port.\nRefer to \"getPort API\" in the manual."
                                                            message:@""
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            //[alert release];
            return;
        }
        
        NSMutableString *message = [NSMutableString string];
        dict = [starPort getFirmwareInformation];
        for (id key in dict.keyEnumerator) {
            [message appendFormat:@"%@: %@\n", key, dict[key]];
        }
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Firmware"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"OK", nil];
        [alert show];
        //[alert release];
    }
    @catch (PortException *exception) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printer Error"
                                                        message:@"Get firmware information failed"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    @finally {
        [SMPort releasePort:starPort];
    }
}

+ (NSInteger)hasBTSettingSupportWithPortName:(NSString *)portName portSettings:(NSString *)portSettings {
    // Check Interface
    if ([portName.uppercaseString hasPrefix:@"BLE:"]) {
        return 0;
    }
    
    if ([portName.uppercaseString hasPrefix:@"BT:"] == NO) {
        return 1;
    }
    
    // Check firmware version
    SMPort *port = nil;
    NSDictionary *dict = nil;
    @try {
        port = [SMPort getPort:portName :portSettings :10000];
        if (port == nil) {
            return 2;
        }
        
        dict = [port getFirmwareInformation];
    }
    @catch (NSException *e) {
        return 2;
    }
    @finally {
        [SMPort releasePort:port];
    }
    
    NSString *modelName = dict[@"ModelName"];
    if ([modelName hasPrefix:@"SM-S21"] ||
        [modelName hasPrefix:@"SM-S22"] ||
        [modelName hasPrefix:@"SM-T30"] ||
        [modelName hasPrefix:@"SM-T40"]) {
        
        NSString *fwVersionStr = dict[@"FirmwareVersion"];
        float fwVersion = fwVersionStr.floatValue;
        if (fwVersion < 3.0) {
            return 3;
        }
    }
    
    return 0;
}

/**
 *  This function is not usable, the cash drawer is not supported by portable printers
 *
 *  @param  portName        Port name to use for communication
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 */
+ (void)OpenCashDrawerWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unsupported" 
                                                    message:@"Cash Drawer is unsupported by portable printers"
                                                   delegate:nil 
                                          cancelButtonTitle:@"OK" 
                                          otherButtonTitles:nil];
    [alert show];
}

/**
 *  This function checks the status of the printer.
 *  The check status function can be used for both portable and non portable printers.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>) or
 *                          (BT:<iOS Port Name>).
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 */
+ (void)CheckStatusWithPortname:(NSString *)portName portSettings:(NSString *)portSettings sensorSetting:(SensorActive)sensorActiveSetting
{
    SMPort *starPort = nil;
    @try
    {
        starPort = [SMPort getPort:portName :portSettings :10000];
        if (starPort == nil)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Fail to Open Port.\nRefer to \"getPort API\" in the manual."
                                                            message:@""
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            //[alert release];
            return;
        }
        usleep(1000 * 1000);
        
        StarPrinterStatus_2 status;
        [starPort getParsedStatus:&status :2];
        
        NSString *message = @"";
        if (status.offline == SM_TRUE)
        {
            message = @"The printer is offline";
            if (status.coverOpen == SM_TRUE)
            {
                message = [message stringByAppendingString:@"\nCover is Open"];
            }
            else if (status.receiptPaperEmpty == SM_TRUE)
            {
                message = [message stringByAppendingString:@"\nOut of Paper"];
            }
        }
        else
        {
            message = @"The Printer is online";
        }
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printer Status"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    @catch (PortException *exception)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printer Error"
                                                        message:@"Get status failed"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    @finally
    {
        [SMPort releasePort:starPort];
    }
}

/**
 *  This function is used to print any of the bar codes supported by the portable printer
 *  This example supports 4 bar code types code39, code93, ITF, code128.  For a complete list of supported bar codes see
 *  manual.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>) or
 *                          (BT:<iOS Port Name>).
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 *  @param  height          The height of the bar code, max is 255
 *  @param  width           Sets the width of the bar code, value of this should be 1 to 8. See pg 34 of the manual for
 *                          the definitions of the values.
 *  @param  type            The type of bar code to print.  This program supports code39, code93, ITF, code128.
 *  @param  barcodeData     The data to print.  The type of characters supported varies.  See pg 35 for a complete list
 *                          of all support characters
 *  @param  barcodeDataSize The size of the barcodeData array.  This is the size of the preceding parameter
 */
+ (void)PrintBarcodeWithPortname:(NSString*)portName portSettings:(NSString*)portSettings height:(unsigned char)height width:(BarcodeWidth)width barcodeType:(BarcodeType)type barcodeData:(unsigned char*)barcodeData barcodeDataSize:(unsigned int)barcodeDataSize
{
    NSMutableData *commands = [[NSMutableData alloc] init];
    
    unsigned char hri_Commands[] = {0x1d, 0x48, 0x01};
    
    [commands appendBytes:hri_Commands length:3];
    
    unsigned char height_Commands[] = {0x1d, 0x68, 0x00};
    height_Commands[2] = height;
    
    [commands appendBytes:height_Commands length:3];
    
    unsigned char width_Commands[] = {0x1d, 0x77, 0x00};
    switch (width)
    {
        case BarcodeWidth_125:
            width_Commands[2] = 1;
            break;
        case BarcodeWidth_250:
            width_Commands[2] = 2;
            break;
        case BarcodeWidth_375:
            width_Commands[2] = 3;
            break;
        case BarcodeWidth_500:
            width_Commands[2] = 4;
            break;
        case BarcodeWidth_625:
            width_Commands[2] = 5;
            break;
        case BarcodeWidth_750:
            width_Commands[2] = 6;
            break;
        case BarcodeWidth_875:
            width_Commands[2] = 7;
            break;
        case BarcodeWidth_1_0:
            width_Commands[2] = 8;
            break;
    }
    [commands appendBytes:width_Commands length:3];
    
    unsigned char *print_Barcode = (unsigned char*)malloc(4 + barcodeDataSize);
    print_Barcode[0] = 0x1d;
    print_Barcode[1] = 0x6b;
    switch (type)
    {
        case BarcodeType_code39:
            print_Barcode[2] = 69;
            break;
        case BarcodeType_ITF:
            print_Barcode[2] = 70;
            break;
        case BarcodeType_code93:
            print_Barcode[2] = 72;
            break;
        case BarcodeType_code128:
            print_Barcode[2] = 73;
            break;
    }
    print_Barcode[3] = barcodeDataSize;
    memcpy(print_Barcode + 4, barcodeData, barcodeDataSize);
    [commands appendBytes:print_Barcode length:4 + barcodeDataSize];
    free(print_Barcode);
    
    unsigned char fiveLineFeeds[] = {0x0a, 0x0a, 0x0a, 0x0a, 0x0a};
    [commands appendBytes:fiveLineFeeds length:5];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];
    
}

/**
 *  The function is used to print a qrcode for the portable printer
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>) or
 *                          (BT:<iOS Port Name>).
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 *  @param  correctionLevel The correction level for the qrcode.  This value should be 0x4C, 0x4D, 0x51, or 0x48.
 *                          See pg 41 for for definition of values
 *  @param  sizeByECLevel   This specifies the symbol version.  This value should be 1 to 40.  See pg 41 for the
 *                          definition of the level
 *  @param  moduleSize      The module size of the qrcode.  This value should be 1 to 8.
 *  @param  barcodeData     The characters to print in the qrcode
 *  @param  barcodeDataSize The number of character to print in the qrcode. This is the size of the preceding parameter.
 */
+ (void)PrintQrcodePortname:(NSString*)portName
               portSettings:(NSString*)portSettings
      correctionLevelOption:(CorrectionLevelOption)correctionLevel
                    ECLevel:(unsigned char)sizeByECLevel
                 moduleSize:(unsigned char)moduleSize
                barcodeData:(unsigned char *)barcodeData
            barcodeDataSize:(unsigned int)barCodeDataSize
{
    NSMutableData *commands = [[NSMutableData alloc] init];
    
    unsigned char initial[] = {0x1b, 0x40};
    [commands appendBytes:initial length:2];
    
    unsigned char selectedBarcodeType[] = {0x1d, 0x5a, 0x02};
    [commands appendBytes:selectedBarcodeType length:3];
    
    unsigned char *print2dbarcode = (unsigned char*)malloc(7 + barCodeDataSize);
    print2dbarcode[0] = 0x1b;
    print2dbarcode[1] = 0x5a;
    print2dbarcode[2] = sizeByECLevel;
    switch (correctionLevel)
    {
        case Low:
            print2dbarcode[3] = 'L';
            break;
        case Middle:
            print2dbarcode[3] = 'M';
            break;
        case Q:
            print2dbarcode[3] = 'Q';
            break;
        case High:
            print2dbarcode[3] = 'H';
            break;
    }
    print2dbarcode[4] = moduleSize;
    print2dbarcode[5] = barCodeDataSize % 256;
    print2dbarcode[6] = barCodeDataSize / 256;
    memcpy(print2dbarcode + 7, barcodeData, barCodeDataSize);
    [commands appendBytes:print2dbarcode length:7 + barCodeDataSize];
    free(print2dbarcode);
    
    unsigned char LF4[] = {0x0a, 0x0a, 0x0a, 0x0a};
    [commands appendBytes:LF4 length:4];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];

}

/**
 * This function prints pdf417 bar codes for portable printers
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>) or
 *                          (BT:<iOS Port Name>).
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 *  @param  width           This is the width of the pdf417 to print.  This is the same width used by the 1d bar codes.
 *                          See pg 34 of the command manual.
 *  @param  columnNumber    This is the column number of the pdf417.  The value of this should be between 1 and 30.
 *  @param  securityLevel   The represents how well the bar code can be restored of damaged.  The value should be
 *                          between 0 and 8.
 *  @param  ratio           The value representing the horizontal and vertical ratio of the bar code. This value should
 *                          between 2 and 5.
 *  @param  barcodeData     The characters that will be in the bar code
 *  @param  barcodeDataSize This is the number of characters that will be in the pdf417 code.  This is the size of the
 *                          preceding parameter
 */
+ (void)PrintPDF417WithPortname:(NSString*)portName portSettings:(NSString*)portSettings width: (BarcodeWidth)width columnNumber:(unsigned char)columnNumber securityLevel:(unsigned char)securityLevel ratio:(unsigned char)ratio barcodeData:(unsigned char *)barcodeData barcodeDataSize: (unsigned char)barcodeDataSize
{
    NSMutableData *commands = [[NSMutableData alloc] init];
    
    unsigned char initial[] = {0x1b, 0x40};
    [commands appendBytes:initial length:2];
    
    unsigned char barcodeWidthCommand[] = {0x1d, 'w', 0x00};
    switch (width)
    {
        case BarcodeWidth_125:
            barcodeWidthCommand[2] = 1;
            break;
        case BarcodeWidth_250:
            barcodeWidthCommand[2] = 2;
            break;
        case BarcodeWidth_375:
            barcodeWidthCommand[2] = 3;
            break;
        case BarcodeWidth_500:
            barcodeWidthCommand[2] = 4;
            break;
        case BarcodeWidth_625:
            barcodeWidthCommand[2] = 5;
            break;
        case BarcodeWidth_750:
            barcodeWidthCommand[2] = 6;
            break;
        case BarcodeWidth_875:
            barcodeWidthCommand[2] = 7;
            break;
        case BarcodeWidth_1_0:
            barcodeWidthCommand[2] = 8;
            break;
    }
    [commands appendBytes:barcodeWidthCommand length:3];
    
    unsigned char setBarcodePDF[] = {0x1d, 0x5a, 0x00};
    [commands appendBytes:setBarcodePDF length:3];
    
    unsigned char *barcodeCommand = (unsigned char*)malloc(7 + barcodeDataSize);
    barcodeCommand[0] = 0x1b;
    barcodeCommand[1] = 0x5a;
    barcodeCommand[2] = columnNumber;
    barcodeCommand[3] = securityLevel;
    barcodeCommand[4] = ratio;
    barcodeCommand[5] = barcodeDataSize % 256;
    barcodeCommand[6] = barcodeDataSize / 256;
    memcpy(barcodeCommand + 7, barcodeData, barcodeDataSize);
    
    [commands appendBytes:barcodeCommand length:7 + barcodeDataSize];
    free(barcodeCommand);
    
    unsigned char LF4[] = {10, 10, 10, 10};
    [commands appendBytes:LF4 length:4];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];
    
}

/**
 * This function is used to print a UIImage directly to a portable printer.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>) or
 *                          (BT:<iOS Port Name>).
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 * @param   source          The UIImage to convert to star printer data for portable printers
 * @param   maxWidth        The maximum with the image to print. This is usually the page with of the printer. If the
 *                          image exceeds the maximum width then the image is scaled down. The ratio is maintained.
 */
+ (void)PrintBitmapWithPortName:(NSString*)portName portSettings:(NSString*)portSettings imageSource:(UIImage*)source printerWidth:(int)maxWidth compressionEnable:(BOOL)compressionEnable pageModeEnable:(BOOL)pageModeEnable
{
    NSMutableData *data = [NSMutableData data];
    
    StarBitmap *starbitmap = [[StarBitmap alloc] initWithUIImage:source :maxWidth :false];
    NSData *commands = [starbitmap getImageMiniDataForPrinting:compressionEnable pageModeEnable:pageModeEnable];
    [data appendData:commands];
    
    u_int8_t feedCommand[] = {0x1b, 0x4A, 0x78}; // feed 120 pixel (15mm)
    [data appendBytes:feedCommand length:3];
    
    [self sendCommand:data portName:portName portSettings:portSettings timeoutMillis:30000];
}

+ (void)sendCommand:(NSData *)commands portName:(NSString *)portName portSettings:(NSString *)portSettings timeoutMillis:(u_int32_t)timeoutMillis
{
    unsigned char *commandsToSendToPrinter = (unsigned char *)malloc(commands.length);
    [commands getBytes:commandsToSendToPrinter length:commands.length];
    int commandSize = (int)commands.length;
    
    SMPort *starPort = nil;
    @try
    {
        starPort = [SMPort getPort:portName :portSettings :timeoutMillis];
        if (starPort == nil)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Fail to Open Port.\nRefer to \"getPort API\" in the manual."
                                                            message:@""
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            //[alert release];
            return;
        }

        struct timeval endTime;
        gettimeofday(&endTime, NULL);
        endTime.tv_sec += 60;
        
        StarPrinterStatus_2 status;
        [starPort beginCheckedBlock:&status :2];
        
        if (status.offline == SM_TRUE)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Printer is offline"
                                                           delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
            [alert show];
            //[alert release];
            return;
        }
        
        int totalAmountWritten = 0;
        while (totalAmountWritten < commandSize)
        {
            int remaining = commandSize - totalAmountWritten;
            
            int amountWritten = [starPort writePort:commandsToSendToPrinter :totalAmountWritten :remaining];
            totalAmountWritten += amountWritten;
            
            struct timeval now;
            gettimeofday(&now, NULL);
            if (now.tv_sec > endTime.tv_sec)
            {
                break;
            }
        }

        starPort.endCheckedBlockTimeoutMillis = 40000;
        [starPort endCheckedBlock:&status :2];
        if (status.offline == SM_TRUE)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"An error has occurred during printing."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
           // [alert release];
            return;
        }
        
        if (totalAmountWritten < commandSize)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printer Error"
                                                            message:@"Write port timed out"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            //[alert release];
            return;
        }
    }
    @catch (PortException *exception)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printer Error"
                                                        message:@"Write port timed out"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        //[alert release];
    }
    @finally
    {
        [SMPort releasePort:starPort];
        free(commandsToSendToPrinter);
    }
}

/**
 *  This function prints raw text to the portable printer.  It show how the text can be formated.  For example changing
 *  its size.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>) or
 *                          (BT:<iOS Port Name>).
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 *  @param  underline       boolean variable that Tells the printer if should underline the text
 *  @param  emphasized      boolean variable that tells the printer if it should emphasize the printed text. This is
 *                          sort of like bold but not as dark, but darker then regular characters.
 *  @param  upsideDown      boolean variable that tells the printer if the text should be printed upside-down
 *  @param  invertColor     boolean variable that tells the printer if it should invert the text its printing.  All
 *                          White space will become black and the characters will be left white
 *  @param  heightExpansion This integer tells the printer what multiple the character height should be, this should be
 *                          from 0 to 7 representing multiples from 1 to 8
 *  @param  widthExpansion  This integer tell the printer what multiple the character width should be, this should be
 *                          from 0 to 7 representing multiples from 1 to 8
 *  @param  leftMargin      The left margin for text on the portable printer.  This number should be be from 0 to 65536
 *                          but it should never get that high or the text can be pushed off the page.
 *  @param  alignment       The alignment of the text. The printers support left, right, and center justification
 *  @param  textToPrint     The text to send to the printer
 *  @param  textToPrintSize The amount of text to send to the printer.  This should be the size of the preceding
 *                          parameter
 */
+ (void)PrintText:(NSString*)portName PortSettings:(NSString*)portSettings Underline:(bool)underline Emphasized:(bool)emphasized Upsideddown:(bool)upsideddown InvertColor:(bool)invertColor HeightExpansion:(unsigned char)heightExpansion WidthExpansion:(unsigned char)widthExpansion LeftMargin:(int)leftMargin Alignment:(Alignment)alignment TextToPrint:(unsigned char*)textToPrint TextToPrintSize:(unsigned int)textToPrintSize;
{
    NSMutableData *commands = [[NSMutableData alloc] init];

	unsigned char initial[] = {0x1b, 0x40};
	[commands appendBytes:initial length:2];
		
    unsigned char underlineCommand[] = {0x1b, 0x2d, 0x00};
    if (underline)
    {
        underlineCommand[2] = 49;
    }
    else
    {
        underlineCommand[2] = 48;
    }
    [commands appendBytes:underlineCommand length:3];
    
    unsigned char emphasizedCommand[] = {0x1b, 0x45, 0x00};
    if (emphasized)
    {
        emphasizedCommand[2] = 1;
    }
    else
    {
        emphasizedCommand[2] = 0;
    }
    [commands appendBytes:emphasizedCommand length:3];
    
    unsigned char upsidedownCommand[] = {0x1b, 0x7b, 0x00};
    if (upsideddown)
    {
        upsidedownCommand[2] = 1;
    }
    else
    {
        upsidedownCommand[2] = 0;
    }
    [commands appendBytes:upsidedownCommand length:3];
    
    unsigned char invertColorCommand[] = {0x1d, 0x42, 0x00};
    if (invertColor)
    {
        invertColorCommand[2] = 1;
    }
    else
    {
        invertColorCommand[2] = 0;
    }
    [commands appendBytes:invertColorCommand length:3];
    
    unsigned char characterSizeCommand[] = {0x1d, 0x21, 0x00};
    characterSizeCommand[2] = heightExpansion | (widthExpansion << 4);
    [commands appendBytes:characterSizeCommand length:3];
    
    unsigned char leftMarginCommand[] = {0x1d, 0x4c, 0x00, 0x00};
    leftMarginCommand[2] = leftMargin % 256;
    leftMarginCommand[3] = leftMargin / 256;
    [commands appendBytes:leftMarginCommand length:4];
    
    unsigned char justificationCommand[] = {0x1b, 0x61, 0x00};
    switch (alignment)
    {
        case Left:
            justificationCommand[2] = 48;
            break;
        case Center:
            justificationCommand[2] = 49;
            break;
        case Right:
            justificationCommand[2] = 50;
            break;
    }
    [commands appendBytes:justificationCommand length:3];
    
    [commands appendBytes:textToPrint length:textToPrintSize];
    
    unsigned char LF = 10;
    [commands appendBytes:&LF length:1];
    [commands appendBytes:&LF length:1];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];

    //[commands release];
}

/**
 *  This function prints raw text of Japanese Kanji to the portable printer. It show how the text can be formated. For
 *  example changing its size.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>) or
 *                          (BT:<iOS Port Name>).
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 *  @param  underline       boolean variable that Tells the printer if should underline the text
 *  @param  emphasized      boolean variable that tells the printer if it should emphasize the printed text. This is
 *                          sort of like bold but not as dark, but darker then regular characters.
 *  @param  upsideDown      boolean variable that tells the printer if the text should be printed upside-down
 *  @param  invertColor     boolean variable that tells the printer if it should invert the text its printing. All White
 *                          space will become black and the characters will be left white
 *  @param  heightExpansion This integer tells the printer what multiple the character height should be, this should be
 *                          from 0 to 7 representing multiples from 1 to 8
 *  @param  widthExpansion  This integer tell the printer what multiple the character width should be, this should be
 *                          from 0 to 7 representing multiples from 1 to 8
 *  @param  leftMargin      The left margin for text on the portable printer.  This number should be be from 0 to 65536
 *                          but it should never get that high or the text can be pushed off the page.
 *  @param  alignment       The alignment of the text. The printers support left, right, and center justification
 *  @param  textToPrint     The text to send to the printer
 *  @param  textToPrintSize The amount of text to send to the printer.  This should be the size of the preceding
 *                          parameter
 */
+ (void)PrintJpKanji:(NSString*)portName PortSettings:(NSString*)portSettings Underline:(bool)underline Emphasized:(bool)emphasized Upsideddown:(bool)upsideddown InvertColor:(bool)invertColor HeightExpansion:(unsigned char)heightExpansion WidthExpansion:(unsigned char)widthExpansion LeftMargin:(int)leftMargin Alignment:(Alignment)alignment TextToPrint:(unsigned char*)textToPrint TextToPrintSize:(unsigned int)textToPrintSize;
{
    NSMutableData *commands = [[NSMutableData alloc] init];
	
	unsigned char initial[] = {0x1b, 0x40};
	[commands appendBytes:initial length:2];
	
	unsigned char kanjiCommand[] = {0x1c, 0x43, 0x01};
	[commands appendBytes:kanjiCommand length:3];
	
    unsigned char underlineCommand[] = {0x1b, 0x2d, 0x00};
    if (underline)
    {
        underlineCommand[2] = 49;
    }
    else
    {
        underlineCommand[2] = 48;
    }
    [commands appendBytes:underlineCommand length:3];
    
    unsigned char emphasizedCommand[] = {0x1b, 0x45, 0x00};
    if (emphasized)
    {
        emphasizedCommand[2] = 1;
    }
    else
    {
        emphasizedCommand[2] = 0;
    }
    [commands appendBytes:emphasizedCommand length:3];
    
    unsigned char upsidedownCommand[] = {0x1b, 0x7b, 0x00};
    if (upsideddown)
    {
        upsidedownCommand[2] = 1;
    }
    else
    {
        upsidedownCommand[2] = 0;
    }
    [commands appendBytes:upsidedownCommand length:3];
    
    unsigned char invertColorCommand[] = {0x1d, 0x42, 0x00};
    if (invertColor)
    {
        invertColorCommand[2] = 1;
    }
    else
    {
        invertColorCommand[2] = 0;
    }
    [commands appendBytes:invertColorCommand length:3];
    
    unsigned char characterSizeCommand[] = {0x1d, 0x21, 0x00};
    characterSizeCommand[2] = heightExpansion | (widthExpansion << 4);
    [commands appendBytes:characterSizeCommand length:3];
    
    unsigned char leftMarginCommand[] = {0x1d, 0x4c, 0x00, 0x00};
    leftMarginCommand[2] = leftMargin % 256;
    leftMarginCommand[3] = leftMargin / 256;
    [commands appendBytes:leftMarginCommand length:4];
    
    unsigned char justificationCommand[] = {0x1b, 0x61, 0x00};
    switch (alignment)
    {
        case Left:
            justificationCommand[2] = 48;
            break;
        case Center:
            justificationCommand[2] = 49;
            break;
        case Right:
            justificationCommand[2] = 50;
            break;
    }
    [commands appendBytes:justificationCommand length:3];
    
    [commands appendBytes:textToPrint length:textToPrintSize];
    
    unsigned char LF = 10;
    [commands appendBytes:&LF length:1];
    [commands appendBytes:&LF length:1];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];

    //[commands release];
}

/**
 *  This function shows how to read the MCR data(credit card) of a portable printer.
 *  The function first puts the printer into MCR read mode, then asks the user to swipe a credit card.
 *  This object then acts as a delegate for the UIAlertView. See alert view responce for seeing how to read the MCR data
 *  one a card has been swiped.
 *  The user can cancel the MCR mode or the read the printer.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>) or
 *                          (BT:<iOS Port Name>).
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 */
- (void)MCRStartWithPortName:(NSString*)portName portSettings:(NSString*)portSettings
{
    starPort = nil;
    @try
    {
        starPort = [SMPort getPort:portName :portSettings :10000];
        if (starPort == nil)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Fail to Open Port.\nRefer to \"getPort API\" in the manual."
                                                            message:@""
                                                           delegate:nil 
                                                  cancelButtonTitle:@"OK" 
                                                  otherButtonTitles:nil];
            [alert show];
            //[alert release];
            return;
        }
        
        struct timeval endTime;
        gettimeofday(&endTime, NULL);
        endTime.tv_sec += 30;
        
        unsigned char startMCRCommand[] = {0x1b, 0x4d, 0x45};
        int commandSize = 3;
        
        int totalAmountWritten = 0;
        while (totalAmountWritten < 3)
        {
            int remaining = commandSize - totalAmountWritten;
            
            int blockSize = (remaining > 1024) ? 1024 : remaining;
            
            int amountWritten = [starPort writePort:startMCRCommand :totalAmountWritten :blockSize];
            totalAmountWritten += amountWritten;
            
            struct timeval now;
            gettimeofday(&now, NULL);
            if (now.tv_sec > endTime.tv_sec)
            {
                break;
            }
        }
        
        if (totalAmountWritten < commandSize)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printer Error" 
                                                            message:@"Write port timed out"
                                                           delegate:nil 
                                                  cancelButtonTitle:@"OK" 
                                                  otherButtonTitles:nil];
            [alert show];
            //[alert release];
            [SMPort releasePort:starPort];
            return;
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"MCR" 
                                                            message:@"Swipe a credit card"
                                                           delegate:self 
                                                  cancelButtonTitle:@"Cancel" 
                                                  otherButtonTitles:@"OK", nil];
            [alert show];
            //[alert release];
        }
    }
    @catch (PortException *exception)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printer Error" 
                                                        message:@"Write port timed out"
                                                       delegate:nil 
                                              cancelButtonTitle:@"OK" 
                                              otherButtonTitles:nil];
        [alert show];
        //[alert release];
    }
}

/**
 *  This is the responce function for reading MCR data.
 *  This will eather cancel the mcr function or read the data.
 */
- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // Read MCR data
    if (buttonIndex != alertView.cancelButtonIndex) {
        @try
        {
            unsigned char dataToRead[100];
            
            int readSize = [starPort readPort:dataToRead :0 :100];
            
            NSString *MCRData = nil;
            if (readSize > 0) {
                MCRData = [NSString stringWithFormat:@"%s",dataToRead];
            } else {
                MCRData = @"NO DATA";
            }
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Card Data" 
                                                            message:MCRData
                                                           delegate:nil 
                                                  cancelButtonTitle:@"OK" 
                                                  otherButtonTitles:nil];
            [alert show];
            //[alert release];
        }
        @catch (PortException *exception)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Card Data" 
                                                            message:@"Failed to read port"
                                                           delegate:nil 
                                                  cancelButtonTitle:@"OK" 
                                                  otherButtonTitles:nil];
            [alert show];
            //[alert release];
        }
    }
    
    // End MCR Mode
    unsigned char endMcrComman = 4;
    int dataWritten = [starPort writePort:&endMcrComman :0 :1];
    if (dataWritten == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printer Error"
                                                        message:@"Write port timed out"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        //[alert release];
    }
    
    [SMPort releasePort:starPort];
}

/*!
 *  This function print the sample receipt
 *
 *  @param  portName        Port name to use for communication
 *  @param  portSettings    Set following settings
 *                          - Portable Printer (ESC/POS Mode)    : @"portable;escpos"
 *                          (* To keep compatibility, can use @"mini")
 *  @param  paperWidth      paper width (2/3/4 [inch])
 *  @param  language        language
 */
+ (void)printSampleReceiptWithPortname:(NSString *)portName portSettings:(NSString *)portSettings paperWidth:(SMPaperWidth)paperWidth language:(SMLanguage)language {
    NSString *languageName = nil;
    switch (language) {
        case SMLanguageEnglish:
            languageName = @"english";
            break;
        case SMLanguageFrench:
            languageName = @"french";
            break;
        case SMLanguagePortuguese:
            languageName = @"portuguese";
            break;
        case SMLanguageSpanish:
            languageName = @"spanish";
            break;
        case SMLanguageJapanese:
            languageName = @"japanese";
            break;
        case SMLanguageTraditionalChinese:
            languageName = @"traditionalChinese";
            break;
        case SMLanguageRussian:
        case SMLanguageSimplifiedChinese:
        default:
            return;
    }
    
    NSString *paperWidthName = nil;
    switch (paperWidth) {
        case SMPaperWidth2inch:
            paperWidthName = @"2inch";
            break;
        case SMPaperWidth3inch:
            paperWidthName = @"3inch";
            break;
        case SMPaperWidth4inch:
            paperWidthName = @"4inch";
            break;
        default:
            return;
    }
    
    NSString *methodName = [NSString stringWithFormat:@"%@%@SampleReceipt", languageName, paperWidthName];
    SEL sel = NSSelectorFromString(methodName);
    if ([self respondsToSelector:sel] == NO) {
        return;
    }
    NSData *commands = [self performSelector:sel];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];
    
    //[commands release];
}

#pragma mark - Sample Receipt Data Generation

/**
 *  This function create the sample receipt data (2inch)
 */
+ (NSData *)english2inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1d\x57\x80\x31"
                   length:sizeof("\x1d\x57\x80\x31") - 1];    // Page Area Setting     <GS> <W> nL nH  (nL = 128, nH = 1)
    
    [commands appendBytes:"\x1b\x61\x01"
                   length:sizeof("\x1b\x61\x01") - 1];    // Center Justification  <ESC> a n       (0 Left, 1 Center, 2 Right)
    
    [commands appendData:[@"Star Clothing Boutique\n"
                          "123 Star Road\n"
                          "City, State 12345\n\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x61\x00"
                   length:sizeof("\x1b\x61\x00") - 1];    // Left Alignment
    
    [commands appendData:[@"Date: MM/DD/YYYY   Time:HH:MM PM\n"
                           "--------------------------------\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x45\x01"
                   length:sizeof("\x1b\x45\x01") - 1];    // Set Emphasized Printing ON
    
    [commands appendData:[@"SALE\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x45\x00"
                   length:sizeof("\x1b\x45\x00") - 1];    // Set Emphasized Printing OFF (same command as on)
    
    [commands appendData:[@"300678566  PLAIN T-SHIRT   10.99\n"
                           "300692003  BLACK DENIM     29.99\n"
                           "300651148  BLUE DENIM      29.99\n"
                           "300642980  STRIPED DRESS   49.99\n"
                           "300638471  BLACK BOOTS     35.99\n\n"
                           "Subtotal                  156.95\n"
                           "Tax                         0.00\n"
                           "--------------------------------\n"
                           "Total "
                          dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendBytes:"\x1d\x21\x11"
                   length:sizeof("\x1d\x21\x11") - 1];    // Width and Height Character Expansion  <GS>  !  n
    
    [commands appendData:[@"      $156.95\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x21\x00"
                   length:sizeof("\x1d\x21\x00") - 1];    // Cancel Expansion - Reference Star Portable Printer Programming Manual
    
    [commands appendData:[@"--------------------------------\n"
                           "Charge\n"
                           "$156.95\n"
                           "Visa XXXX-XXXX-XXXX-0123\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x77\x02"
                   length:sizeof("\x1d\x77\x02") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\x1d\x68\x64"
                   length:sizeof("\x1d\x68\x64") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\x1d\x48\x01"
                   length:sizeof("\x1d\x48\x01") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\x1d\x6b\x41\x0b\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x30"
                   length:sizeof("\x1d\x6b\x41\x0b\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x30") - 1];    // for 1D Code39 Barcode
    
    [commands appendData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x42\x01"
                   length:sizeof("\x1d\x42\x01") - 1];    // Specify White-Black Invert
    
    [commands appendData:[@"Refunds and Exchanges\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x42\x00"
                   length:sizeof("\x1d\x42\x00") - 1];    // Cancel White-Black Invert
    
    [commands appendData:[@"Within " dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x2d\x01"
                   length:sizeof("\x1b\x2d\x01") - 1];    // Specify Underline Printing
    
    [commands appendData:[@"30 days" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x2d\x00"
                   length:sizeof("\x1b\x2d\x00") - 1];    // Cancel Underline Printing
    
    [commands appendData:[@" with receipt\n"
                           "And tags attached\n"
                           "-------------Sign Here----------\n\n\n"
                           "--------------------------------\n"
                           "Thank you for buying Star!\n"
                           "Scan QR Code to visit our site!\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x5a\x02"
                   length:sizeof("\x1d\x5a\x02") - 1];    // Cancel Underline Printing
    
    [commands appendBytes:"\x1d\x5a\x02\x1b\x5a\x00\x51\x04"
                          "\x1C\x00\x68\x74\x74\x70\x3a\x2f"
                          "\x2f\x77\x77\x77\x2e\x53\x74\x61"
                          "\x72\x4d\x69\x63\x72\x6f\x6e\x69"
                          "\x63\x73\x2e\x63\x6f\x6d"
                   length:sizeof("\x1d\x5a\x02\x1b\x5a\x00\x51\x04"
                                 "\x1C\x00\x68\x74\x74\x70\x3a\x2f"
                                 "\x2f\x77\x77\x77\x2e\x53\x74\x61"
                                 "\x72\x4d\x69\x63\x72\x6f\x6e\x69"
                                 "\x63\x73\x2e\x63\x6f\x6d") - 1];
    
    [commands appendData:[@"\n\n\n\n\n" dataUsingEncoding:NSASCIIStringEncoding]];

    return commands;
}

/**
 *  This function create the sample receipt data (3inch)
 */
+ (NSData *)english3inchSampleReceipt {
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1d\x57\x40\x32"
                   length:sizeof("\x1d\x57\x40\x32") - 1];    // Page Area Setting     <GS> <W> nL nH  (nL = 64, nH = 2)
    
    [commands appendBytes:"\x1b\x61\x01"
                   length:sizeof("\x1b\x61\x01") - 1];    // Center Justification  <ESC> a n       (0 Left, 1 Center, 2 Right)
    
    [commands appendData:[@"Star Clothing Boutique\n"
                           "123 Star Road\n"
                          "City, State 12345\n\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x61\x00"
                   length:sizeof("\x1b\x61\x00") - 1];    // Left Alignment
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00"
                   length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1];    // Setting Horizontal Tab
    
    [commands appendData:[@"Date: MM/DD/YYYY " dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x09"
                   length:sizeof("\x09") - 1];    // Left Alignment"
    
    [commands appendData:[@"Time: HH:MM PM\n"
                           "------------------------------------------------\n"
                           dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x45\x01"
                   length:sizeof("\x1b\x45\x01") - 1];    // Set Emphasized Printing ON
    
    [commands appendData:[@"SALE\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x45\x00"
                   length:sizeof("\x1b\x45\x00") - 1];    // Set Emphasized Printing OFF (same command as on)
    
    [commands appendData:[@"300678566    PLAIN T-SHIRT                 10.99\n"
                           "300692003    BLACK DENIM                   29.99\n"
                           "300651148    BLUE DENIM                    29.99\n"
                           "300642980    STRIPED DRESS                 49.99\n"
                           "300638471    BLACK BOOTS                   35.99\n\n"
                           "Subtotal                                  156.95\n"
                           "Tax                                         0.00\n"
                           "------------------------------------------------\n"
                           "Total   " dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x21\x11"
                   length:sizeof("\x1d\x21\x11") - 1];    // Width and Height Character Expansion  <GS>  !  n
    
    [commands appendData:[@"             $156.95\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x21\x00"
                   length:sizeof("\x1d\x21\x00") - 1];    // Cancel Expansion - Reference Star Portable Printer Programming Manual
    
    [commands appendData:[@"------------------------------------------------\n"
                           "Charge\n"
                           "$156.95\n"
                           "Visa XXXX-XXXX-XXXX-0123\n" dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendBytes:"\x1d\x77\x02"
                   length:sizeof("\x1d\x77\x02") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\x1d\x68\x64"
                   length:sizeof("\x1d\x68\x64") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\x1d\x48\x01"
                   length:sizeof("\x1d\x48\x01") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\x1d\x6b\x41\x0b\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x30"
                   length:sizeof("\x1d\x6b\x41\x0b\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x30") - 1];    // for 1D Code39 Barcode
    
    [commands appendData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x42\x01"
                   length:sizeof("\x1d\x42\x01") - 1];    // Specify White-Black Invert
    
    [commands appendData:[@"Refunds and Exchanges\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x42\x00"
                   length:sizeof("\x1d\x42\x00") - 1];    // Cancel White-Black Invert
    
    [commands appendData:[@"Within " dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x2d\x01"
                   length:sizeof("\x1b\x2d\x01") - 1];    // Specify Underline Printing
    
    [commands appendData:[@"30 days" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x2d\x00"
                   length:sizeof("\x1b\x2d\x00") - 1];    // Cancel Underline Printing
    
    [commands appendData:[@" with receipt\n"
                           "And tags attached\n"
                           "------------- Card Holder's Signature ----------\n\n\n"
                           "------------------------------------------------\n"
                           "Thank you for buying Star!\n"
                           "Scan QR Code to visit our site!\n"
                          dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendBytes:"\x1d\x5a\x02"
                   length:sizeof("\x1d\x5a\x02") - 1];    // Cancel Underline Printing
    
    [commands appendBytes:"\x1d\x5a\x02\x1b\x5a\x00\x51\x04"
                          "\x1C\x00\x68\x74\x74\x70\x3a\x2f"
                          "\x2f\x77\x77\x77\x2e\x53\x74\x61"
                          "\x72\x4d\x69\x63\x72\x6f\x6e\x69"
                          "\x63\x73\x2e\x63\x6f\x6d"
                   length:sizeof("\x1d\x5a\x02\x1b\x5a\x00\x51\x04"
                                 "\x1C\x00\x68\x74\x74\x70\x3a\x2f"
                                 "\x2f\x77\x77\x77\x2e\x53\x74\x61"
                                 "\x72\x4d\x69\x63\x72\x6f\x6e\x69"
                                 "\x63\x73\x2e\x63\x6f\x6d") - 1];    // PrintBarcode
    
    [commands appendData:[@"\n\n\n\n\n" dataUsingEncoding:NSASCIIStringEncoding]];

    return commands;
}

/**
 *  This function create the sample receipt data (4inch)
 */
+ (NSData *)english4inchSampleReceipt {
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1d\x57\x40\x32"
                   length:sizeof("\x1d\x57\x40\x32") - 1];    // Page Area Setting     <GS> <W> nL nH  (nL = 64, nH = 2)
    
    [commands appendBytes:"\x1b\x61\x01"
                   length:sizeof("\x1b\x61\x01") - 1];    // Center Justification  <ESC> a n       (0 Left, 1 Center, 2 Right)
    
    [commands appendData:[@"Star Clothing Boutique\n"
                            "123 Star Road\n"
                            "City, State 12345\n\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x61\x00"
                   length:sizeof("\x1b\x61\x00") - 1];    // Left Alignment
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00"
                   length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1];    // Setting Horizontal Tab
    
    [commands appendData:[@"Date: MM/DD/YYYY " dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x09"
                   length:sizeof("\x09") - 1];    // Left Alignment"
    
    [commands appendData:[@"Time: HH:MM PM\n"
                           "---------------------------------------------------------------------\n"
                          dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x45\x01"
                   length:sizeof("\x1b\x45\x01") - 1];    // Set Emphasized Printing ON
    
    [commands appendData:[@"SALE\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x45\x00"
                   length:sizeof("\x1b\x45\x00") - 1];    // Set Emphasized Printing OFF (same command as on)
    
    [commands appendData:[@"300678566              PLAIN T-SHIRT                            10.99\n"
                           "300692003              BLACK DENIM                              29.99\n"
                           "300651148              BLUE DENIM                               29.99\n"
                           "300642980              STRIPED DRESS                            49.99\n"
                           "300638471              BLACK BOOTS                              35.99\n\n"
                           "Subtotal                                                       156.95\n"
                           "Tax                                                              0.00\n"
                           "---------------------------------------------------------------------\n"
                           "Total   " dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x21\x11"
                   length:sizeof("\x1d\x21\x11") - 1];    // Width and Height Character Expansion  <GS>  !  n
    
    [commands appendData:[@"             $156.95\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x21\x00"
                   length:sizeof("\x1d\x21\x00") - 1];    // Cancel Expansion - Reference Star Portable Printer Programming Manual
    
    [commands appendData:[@"---------------------------------------------------------------------\n"
                           "Charge\n"
                           "$156.95\n"
                           "Visa XXXX-XXXX-XXXX-0123\n"
                          dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x77\x02"
                   length:sizeof("\x1d\x77\x02") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\x1d\x68\x64"
                   length:sizeof("\x1d\x68\x64") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\x1d\x48\x01"
                   length:sizeof("\x1d\x48\x01") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\x1d\x6b\x41\x0b\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x30"
                   length:sizeof("\x1d\x6b\x41\x0b\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x30") - 1];    // for 1D Code39 Barcode
    
    [commands appendData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x42\x01"
                   length:sizeof("\x1d\x42\x01") - 1];    // Specify White-Black Invert
    
    [commands appendData:[@"Refunds and Exchanges\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x42\x00"
                   length:sizeof("\x1d\x42\x00") - 1];    // Cancel White-Black Invert
    
    [commands appendData:[@"Within " dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x2d\x01"
                   length:sizeof("\x1b\x2d\x01") - 1];    // Specify Underline Printing
    
    [commands appendData:[@"30 days" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x2d\x00"
                   length:sizeof("\x1b\x2d\x00") - 1];    // Cancel Underline Printing
    
    [commands appendData:[@" with receipt\n"
                           "And tags attached\n"
                           "----------------------- Card Holder's Signature ---------------------\n\n\n"
                           "---------------------------------------------------------------------\n"
                           "Thank you for buying Star!\n"
                           "Scan QR Code to visit our site!\n"
                          dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1d\x5a\x02"
                   length:sizeof("\x1d\x5a\x02") - 1];    // Cancel Underline Printing
    
    [commands appendBytes:"\x1d\x5a\x02\x1b\x5a\x00\x51\x04"
                          "\x1C\x00\x68\x74\x74\x70\x3a\x2f"
                          "\x2f\x77\x77\x77\x2e\x53\x74\x61"
                          "\x72\x4d\x69\x63\x72\x6f\x6e\x69"
                          "\x63\x73\x2e\x63\x6f\x6d"
                   length:sizeof("\x1d\x5a\x02\x1b\x5a\x00\x51\x04"
                                 "\x1C\x00\x68\x74\x74\x70\x3a\x2f"
                                 "\x2f\x77\x77\x77\x2e\x53\x74\x61"
                                 "\x72\x4d\x69\x63\x72\x6f\x6e\x69"
                                 "\x63\x73\x2e\x63\x6f\x6d") - 1];    // PrintBarcode
    
    [commands appendData:[@"\n\n\n\n\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    return commands;
}

/**
 *  This function create the french sample receipt data (2inch)
 */
+ (NSData *)french2inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1c\x43\x00" length:sizeof("\x1c\x43\x00") - 1]; // Disable Kanji mode
    
    [commands appendBytes:"\x1b\x74\x11" length:sizeof("\x1b\x74\x11") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x11" length:sizeof("\x1d\x21\x11") - 1];

    [commands appendData:[@"\nORANGE\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"36 AVENUE LA MOTTE PICQUET\r\n\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendData:[@"--------------------------------\r\n"
                           "Date   : MM/DD/YYYY\r\n"
                           "Heure  : HH:MM\r\n"
                           "Boutique: OLUA23    Caisse: 0001\r\n"
                           "Conseiller: 002970  Ticket: 3881\r\n"
                           "--------------------------------\r\n\r\n"
                           "Vous avez été servi par : Souad\r\n\r\n"
                           "CAC IPHONE ORANGE\r\n"
                           "3700615033581 1 X 19.99€  19.99€\r\n\r\n"
                           "dont contribution\r\n environnementale :\r\n"
                           "CAC IPHONE ORANGE          0.01€\r\n"
                           "--------------------------------\r\n"
                           "    1 Piéce(s)   Total :  19.99€\r\n"
                           "      Mastercard Visa  :  19.99€\r\n\r\n"
                           "Taux TVA    Montant H.T.   T.V.A\r\n"
                           "  20%          16.66€      3.33€\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"Merci de votre visite et.\r\n"
                           "à bientôt.\r\n"
                           "Conservez votre ticket il\r\n"
                           "vous sera demandé pour \r\n"
                           "tout échange.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1];
    
    Byte qrcodeByteBuffer[] = {
        0x1d, 0x5a, 0x02, 0x1b, 0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00,
        0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77,
        0x2e, 0x53, 0x74, 0x61, 0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f,
        0x6e, 0x69, 0x63, 0x73, 0x2e, 0x63, 0x6f, 0x6d};
    [commands appendBytes:qrcodeByteBuffer length:sizeof(qrcodeByteBuffer)]; // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendData:[@"\n\n\n\n" dataUsingEncoding:ENCODING]];
    
    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

/**
 *  This function create the french sample receipt data (3inch)
 */
+ (NSData *)french3inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1c\x43\x00" length:sizeof("\x1c\x43\x00") - 1]; // Disable Kanji mode
    
    [commands appendBytes:"\x1b\x74\x11" length:sizeof("\x1b\x74\x11") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x11" length:sizeof("\x1d\x21\x11") - 1];

    [commands appendData:[@"\nORANGE\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"36 AVENUE LA MOTTE PICQUET\r\n\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendData:[@"------------------------------------------------\r\n"
                           "Date   : MM/DD/YYYY   Heure: HH:MM\r\n"
                           "Boutique: OLUA23      Caisse: 0001\r\n"
                           "Conseiller: 002970    Ticket: 3881\r\n"
                           "------------------------------------------------\r\n\r\n"
                           "Vous avez été servi par : Souad\r\n\r\n"
                           "CAC IPHONE ORANGE\r\n"
                           "3700615033581   1   X   19.99€       19.99€\r\n\r\n"
                           "dont contribution environnementale :\r\n"
                           "CAC IPHONE ORANGE                     0.01€\r\n"
                           "------------------------------------------------\r\n"
                           "    1 Piéce(s)   Total :             19.99€\r\n"
                           "      Mastercard Visa  :             19.99€\r\n\r\n"
                           "Taux TVA    Montant H.T.   T.V.A\r\n"
                           "  20%          16.66€      3.33€\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"Merci de votre visite et. à bientôt.\r\n"
                           "Conservez votre ticket il\r\n"
                           "vous sera demandé pour tout échange.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1];
    
    Byte qrcodeByteBuffer[] = {
        0x1d, 0x5a, 0x02, 0x1b, 0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00,
        0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77,
        0x2e, 0x53, 0x74, 0x61, 0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f,
        0x6e, 0x69, 0x63, 0x73, 0x2e, 0x63, 0x6f, 0x6d};
    [commands appendBytes:qrcodeByteBuffer length:sizeof(qrcodeByteBuffer)]; // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendData:[@"\n\n\n\n" dataUsingEncoding:ENCODING]];
    
    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

/**
 *  This function create the french sample receipt data (4inch)
 */
+ (NSData *)french4inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1c\x43\x00" length:sizeof("\x1c\x43\x00") - 1]; // Disable Kanji mode
    
    [commands appendBytes:"\x1b\x74\x11" length:sizeof("\x1b\x74\x11") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x11" length:sizeof("\x1d\x21\x11") - 1];


    [commands appendData:[@"\nORANGE\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"36 AVENUE LA MOTTE PICQUET\r\n\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab

    [commands appendData:[@"---------------------------------------------------------------------\r\n"
                           "Date   : MM/DD/YYYY   Heure: HH:MM\r\n"
                           "Boutique: OLUA23      Caisse: 0001\r\n"
                           "Conseiller: 002970    Ticket: 3881\r\n"
                           "---------------------------------------------------------------------\r\n\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendData:[@"Vous avez été servi par : Souad\r\n\r\n"
                           "CAC IPHONE ORANGE\r\n"
                           "3700615033581        1        X        19.99€                 19.99€\r\n\r\n"
                           "dont contribution environnementale :\r\n"
                           "CAC IPHONE ORANGE                                              0.01€\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "         1 Piéce(s)        Total :                            19.99€\r\n"
                           "                Mastercard Visa  :                            19.99€\r\n\r\n"
                           "Taux TVA    Montant H.T.   T.V.A\r\n"
                           "  20%          16.66€      3.33€\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"Merci de votre visite et. à bientôt. Conservez votre ticket il\r\n"
                           "vous sera demandé pour tout échange.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1];
    
    Byte qrcodeByteBuffer[] = {
        0x1d, 0x5a, 0x02, 0x1b, 0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00,
        0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77,
        0x2e, 0x53, 0x74, 0x61, 0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f,
        0x6e, 0x69, 0x63, 0x73, 0x2e, 0x63, 0x6f, 0x6d};
    [commands appendBytes:qrcodeByteBuffer length:sizeof(qrcodeByteBuffer)]; // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendData:[@"\n\n\n\n" dataUsingEncoding:ENCODING]];
    
    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

/**
 *  This function create the portuguese sample receipt data (2inch)
 */
+ (NSData *)portuguese2inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1c\x43\x00" length:sizeof("\x1c\x43\x00") - 1]; // Disable Kanji mode
    
    [commands appendBytes:"\x1b\x74\x11" length:sizeof("\x1b\x74\x11") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x10" length:sizeof("\x1d\x21\x10") - 1];

    [commands appendData:[@"\nCOMERCIAL DE ALIMENTOS\r\n"
            "CARREFOUR LTDA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendData:[@"Avenida Moyses Roysen,\r\n"
                           "S/N Vila Guilherme\r\n"
                           "Cep: 02049-010 – Sao Paulo – SP\r\n"
                           "CNPJ: 62.545.579/0013-69\r\n"
                           "IE:110.819.138.118\r\n"
                           "IM: 9.041.041-5\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendData:[@"--------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendData:[@"MM/DD/YYYY HH:MM:SS\r\n"
                           "CCF:133939 COO:227808\r\n"
                           "--------------------------------\r\n"
                           "CUPOM FISCAL\r\n"
                           "--------------------------------\r\n"
                           "001 2505 CAFÉ DO PONTO TRAD A\r\n"
                           "                    1un F1 8,15)\r\n"
                           "002 2505 CAFÉ DO PONTO TRAD A\r\n"
                           "                    1un F1 8,15)\r\n"
                           "003 2505 CAFÉ DO PONTO TRAD A\r\n"
                           "                    1un F1 8,15)\r\n"
                           "004 6129 AGU MIN NESTLE 510ML\r\n"
                           "                    1un F1 1,39)\r\n"
                           "005 6129 AGU MIN NESTLE 510ML\r\n"
                           "                    1un F1 1,39)\r\n"
                           "--------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x01" length:sizeof("\x1d\x21\x01") - 1];
    
    [commands appendData:[@"TOTAL  R$  27,23\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendData:[@"DINHEIROv                29,00\r\n"
                           "TROCO R$                    1,77\r\n"
                           "Valor dos Tributos R$2,15(7,90%)\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"ITEM(S) CINORADIS 5\r\n"
                           "OP.:15326  PDV:9  BR,BF:93466\r\n"
                           "OBRIGADO PERA PREFERENCIA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x01" length:sizeof("\x1d\x21\x01") - 1];
    
    [commands appendData:[@"VOLTE SEMPRE!\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendData:[@"SAC 0800 724 2822\r\n"
                           "--------------------------------\r\n"
                           "MD5:\r\n"
                           "fe028828a532a7dbaf4271155aa4e2db\r\n"
                           "Calypso_CA CA.20.c13\r\n"
                           " – Unisys Brasil\r\n"
                           "--------------------------------\r\n"
                           "DARUMA AUTOMAÇÃO   MACH 2\r\n"
                           "ECF-IF VERSÃO:01,00,00 ECF:093\r\n"
                           "Lj:0204 OPR:ANGELA JORGE\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"DDDDDDDDDAEHFGBFCC\r\n"
                           "MM/DD/YYYY HH:MM:SS\r\n"
                           "FAB:DR0911BR000000275026\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    Byte qrcodeByteBuffer[] = {
        0x1d, 0x5a, 0x02, 0x1b, 0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00,
        0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77,
        0x2e, 0x53, 0x74, 0x61, 0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f,
        0x6e, 0x69, 0x63, 0x73, 0x2e, 0x63, 0x6f, 0x6d};
    [commands appendBytes:qrcodeByteBuffer length:sizeof(qrcodeByteBuffer)]; // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendData:[@"\n\n\n\n" dataUsingEncoding:ENCODING]];
    
    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

/**
 *  This function create the portuguese sample receipt data (3inch)
 */
+ (NSData *)portuguese3inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1c\x43\x00" length:sizeof("\x1c\x43\x00") - 1]; // Disable Kanji mode
    
    [commands appendBytes:"\x1b\x74\x11" length:sizeof("\x1b\x74\x11") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x10" length:sizeof("\x1d\x21\x10") - 1];

    [commands appendData:[@"\nCOMERCIAL DE ALIMENTOS CARREFOUR LTDA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendData:[@"Avenida Moyses Roysen, S/N Vila Guilherme\r\n"
                           "Cep: 02049-010 – Sao Paulo – SP\r\n"
                           "CNPJ: 62.545.579/0013-69\r\n"
                           "IE:110.819.138.118  IM: 9.041.041-5\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendData:[@"------------------------------------------------\r\n"
                           "MM/DD/YYYY HH:MM:SS  CCF:133939 COO:227808\r\n"
                           "------------------------------------------------\r\n"
                           "CUPOM FISCAL\r\n"
                           "------------------------------------------------\r\n"
                           "001 2505 CAFÉ DO PONTO TRAD A       1un F1 8,15)\r\n"
                           "002 2505 CAFÉ DO PONTO TRAD A       1un F1 8,15)\r\n"
                           "003 2505 CAFÉ DO PONTO TRAD A       1un F1 8,15)\r\n"
                           "004 6129 AGU MIN NESTLE 510ML       1un F1 1,39)\r\n"
                           "005 6129 AGU MIN NESTLE 510ML       1un F1 1,39)\r\n"
                           "------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x01" length:sizeof("\x1d\x21\x01") - 1];
    
    [commands appendData:[@"TOTAL  R$  27,23\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendBytes:"\x1b\x61\x02" length:sizeof("\x1b\x61\x02") - 1]; // Alignment
    
    [commands appendData:[@"DINHEIROv                29,00\r\n"
                           "TROCO R$                  1,77\r\n"
                           "Valor dos Tributos R$2,15(7,90%)\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"ITEM(S) CINORADIS 5\r\n"
                           "OP.:15326  PDV:9  BR,BF:93466\r\n"
                           "OBRIGADO PERA PREFERENCIA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x01" length:sizeof("\x1d\x21\x01") - 1];
    
    [commands appendData:[@"VOLTE SEMPRE!\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"SAC 0800 724 2822\r\n"
                           "------------------------------------------------\r\n"
                           "MD5: fe028828a532a7dbaf4271155aa4e2db\r\n"
                           "Calypso_CA CA.20.c13  – Unisys Brasil\r\n"
                           "------------------------------------------------\r\n"
                           "DARUMA AUTOMAÇÃO   MACH 2\r\n"
                           "ECF-IF VERSÃO:01,00,00 ECF:093\r\n"
                           "Lj:0204 OPR:ANGELA JORGE\r\n"
                           "DDDDDDDDDAEHFGBFCC\r\n"
                           "MM/DD/YYYY HH:MM:SS\r\n"
                           "FAB:DR0911BR000000275026\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    Byte qrcodeByteBuffer[] = {
        0x1d, 0x5a, 0x02, 0x1b, 0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00,
        0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77,
        0x2e, 0x53, 0x74, 0x61, 0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f,
        0x6e, 0x69, 0x63, 0x73, 0x2e, 0x63, 0x6f, 0x6d};
    [commands appendBytes:qrcodeByteBuffer length:sizeof(qrcodeByteBuffer)]; // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendData:[@"\n\n\n\n" dataUsingEncoding:ENCODING]];
    
    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

/**
 *  This function create the portuguese sample receipt data (4inch)
 */
+ (NSData *)portuguese4inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1c\x43\x00" length:sizeof("\x1c\x43\x00") - 1]; // Disable Kanji mode
    
    [commands appendBytes:"\x1b\x74\x11" length:sizeof("\x1b\x74\x11") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x10" length:sizeof("\x1d\x21\x10") - 1];

    [commands appendData:[@"\nCOMERCIAL DE ALIMENTOS CARREFOUR LTDA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendData:[@"Avenida Moyses Roysen, S/N Vila Guilherme\r\n"
                           "Cep: 02049-010 – Sao Paulo – SP\r\n"
                           "CNPJ: 62.545.579/0013-69\r\n"
                           "IE:110.819.138.118  IM: 9.041.041-5\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "MM/DD/YYYY HH:MM:SS  CCF:133939 COO:227808\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendData:[@"---------------------------------------------------------------------\r\n"
                           "CUPOM FISCAL\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "001   2505     CAFÉ DO PONTO TRAD A                      1un F1 8,15)\r\n"
                           "002   2505     CAFÉ DO PONTO TRAD A                      1un F1 8,15)\r\n"
                           "003   2505     CAFÉ DO PONTO TRAD A                      1un F1 8,15)\r\n"
                           "004   6129     AGU MIN NESTLE 510ML                      1un F1 1,39)\r\n"
                           "005   6129     AGU MIN NESTLE 510ML                      1un F1 1,39)\r\n"
                           "---------------------------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x01" length:sizeof("\x1d\x21\x01") - 1];
    
    [commands appendData:[@"TOTAL  R$  27,23\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendBytes:"\x1b\x61\x02" length:sizeof("\x1b\x61\x02") - 1]; // Alignment
    
    [commands appendData:[@"DINHEIROv                29,00\r\n"
                           "TROCO R$                  1,77\r\n"
                           "Valor dos Tributos R$2,15(7,90%)\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"ITEM(S) CINORADIS 5\r\n"
                           "OP.:15326  PDV:9  BR,BF:93466\r\n"
                           "OBRIGADO PERA PREFERENCIA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x01" length:sizeof("\x1d\x21\x01") - 1];
    
    [commands appendData:[@"VOLTE SEMPRE!\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"SAC 0800 724 2822\r\n"
                            "---------------------------------------------------------------------\r\n"
                            "MD5: fe028828a532a7dbaf4271155aa4e2db\r\n"
                            "Calypso_CA CA.20.c13  – Unisys Brasil\r\n"
                            "---------------------------------------------------------------------\r\n"
                            "DARUMA AUTOMAÇÃO   MACH 2\r\n"
                            "ECF-IF VERSÃO:01,00,00 ECF:093\r\n"
                            "Lj:0204 OPR:ANGELA JORGE\r\n"
                            "DDDDDDDDDAEHFGBFCC\r\n"
                            "MM/DD/YYYY HH:MM:SS\r\n"
                            "FAB:DR0911BR000000275026\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    Byte qrcodeByteBuffer[] = {
        0x1d, 0x5a, 0x02, 0x1b, 0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00,
        0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77,
        0x2e, 0x53, 0x74, 0x61, 0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f,
        0x6e, 0x69, 0x63, 0x73, 0x2e, 0x63, 0x6f, 0x6d};
    [commands appendBytes:qrcodeByteBuffer length:sizeof(qrcodeByteBuffer)]; // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendData:[@"\n\n\n\n" dataUsingEncoding:ENCODING]];
    
    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

/**
 *  This function create the spanish sample receipt data (2inch)
 */
+ (NSData *)spanish2inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1c\x43\x00" length:sizeof("\x1c\x43\x00") - 1]; // Disable Kanji mode
    
    [commands appendBytes:"\x1b\x74\x11" length:sizeof("\x1b\x74\x11") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x11" length:sizeof("\x1d\x21\x11") - 1];

    [commands appendData:[@"BAR RESTAURANT\r\n"
            "EL POZO\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendData:[@"C/.ROCAFORT 187\r\n"
                           "08029 BARCELONA\r\n\r\n"
                           "NIF :X-3856907Z\r\n"
                           "TEL :934199465\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendData:[@"--------------------------------\r\n"
                           "MESA: 100 P: - FECHA: YYYY-MM-DD\r\n"
                           "CAN P/U DESCRIPCION  SUMA\r\n"
                           "--------------------------------\r\n"
                           " 4  3,00  JARRA  CERVESA   12,00\r\n"
                           " 1  1,60  COPA DE CERVESA   1,60\r\n"
                           "--------------------------------\r\n"
                           "               SUB TOTAL : 13,60\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x01" length:sizeof("\x1d\x21\x01") - 1];
    
    [commands appendBytes:"\x1b\x61\x02" length:sizeof("\x1b\x61\x02") - 1]; // Alignment
    
    [commands appendData:[@"TOTAL:     13,60 EUROS\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendData:[@"NO: 000018851     IVA INCLUIDO\r\n"
            "--------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"**** GRACIAS POR SU VISITA! ****\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    Byte qrcodeByteBuffer[] = {
        0x1d, 0x5a, 0x02, 0x1b, 0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00,
        0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77,
        0x2e, 0x53, 0x74, 0x61, 0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f,
        0x6e, 0x69, 0x63, 0x73, 0x2e, 0x63, 0x6f, 0x6d};
    [commands appendBytes:qrcodeByteBuffer length:sizeof(qrcodeByteBuffer)]; // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendData:[@"\n\n\n\n" dataUsingEncoding:ENCODING]];
    
    return commands;
}

/**
 *  This function create the spanish sample receipt data (3inch)
 */
+ (NSData *)spanish3inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;
    
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1c\x43\x00" length:sizeof("\x1c\x43\x00") - 1]; // Disable Kanji mode
    
    [commands appendBytes:"\x1b\x74\x11" length:sizeof("\x1b\x74\x11") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x11" length:sizeof("\x1d\x21\x11") - 1];
    
    [commands appendData:[@"BAR RESTAURANT EL POZO\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendData:[@"C/.ROCAFORT 187 08029 BARCELONA\r\n"
                           "NIF :X-3856907Z  TEL :934199465\r\n"
                           "------------------------------------------------\r\n"
                           "MESA: 100 P: - FECHA: YYYY-MM-DD\r\n"
                           "CAN P/U DESCRIPCION  SUMA\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendData:[@"------------------------------------------------\r\n"
                           " 4    3,00      JARRA  CERVESA             12,00\r\n"
                           " 1    1,60      COPA DE CERVESA             1,60\r\n"
                           "------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x02" length:sizeof("\x1b\x61\x02") - 1]; // Alignment
    
    [commands appendData:[@"SUB TOTAL : 13,60\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x01" length:sizeof("\x1d\x21\x01") - 1];
    
    [commands appendData:[@"TOTAL:     13,60 EUROS\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendData:[@"NO: 000018851     IVA INCLUIDO\r\n"
                          "------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"**** GRACIAS POR SU VISITA! ****\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    Byte qrcodeByteBuffer[] = {
        0x1d, 0x5a, 0x02, 0x1b, 0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00,
        0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77,
        0x2e, 0x53, 0x74, 0x61, 0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f,
        0x6e, 0x69, 0x63, 0x73, 0x2e, 0x63, 0x6f, 0x6d};
    [commands appendBytes:qrcodeByteBuffer length:sizeof(qrcodeByteBuffer)]; // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendData:[@"\n\n\n\n" dataUsingEncoding:ENCODING]];
    
    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

/**
 *  This function create the spanish sample receipt data (4inch)
 */
+ (NSData *)spanish4inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;
    
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1c\x43\x00" length:sizeof("\x1c\x43\x00") - 1]; // Disable Kanji mode
    
    [commands appendBytes:"\x1b\x74\x11" length:sizeof("\x1b\x74\x11") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1d\x21\x11" length:sizeof("\x1d\x21\x11") - 1];
    
    [commands appendData:[@"BAR RESTAURANT EL POZO\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendData:[@"C/.ROCAFORT 187 08029 BARCELONA\r\n"
                           "NIF :X-3856907Z  TEL :934199465\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "MESA: 100 P: - FECHA: YYYY-MM-DD\r\n"
                           "CAN P/U DESCRIPCION  SUMA\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendData:[@"---------------------------------------------------------------------\r\n"
                           " 4        3,00          JARRA  CERVESA                        \r\n"
                           " 1        1,60          COPA DE CERVESA                       \r\n"
                           "---------------------------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x02" length:sizeof("\x1b\x61\x02") - 1]; // Alignment
    
    [commands appendData:[@"SUB TOTAL         :     13,60\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1d\x21\x01" length:sizeof("\x1d\x21\x01") - 1];
    
    [commands appendData:[@"TOTAL    :    13,60 EUROS\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    [commands appendBytes:"\x1d\x21\x00" length:sizeof("\x1d\x21\x00") - 1];
    
    [commands appendData:[@"NO: 000018851                 IVA INCLUIDO\r\n"
                           "---------------------------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x01" length:sizeof("\x1b\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"**** GRACIAS POR SU VISITA! ****\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x61\x00" length:sizeof("\x1b\x61\x00") - 1]; // Alignment
    
    Byte qrcodeByteBuffer[] = {
        0x1d, 0x5a, 0x02, 0x1b, 0x5a, 0x00, 0x51, 0x04, 0x1C, 0x00,
        0x68, 0x74, 0x74, 0x70, 0x3a, 0x2f, 0x2f, 0x77, 0x77, 0x77,
        0x2e, 0x53, 0x74, 0x61, 0x72, 0x4d, 0x69, 0x63, 0x72, 0x6f,
        0x6e, 0x69, 0x63, 0x73, 0x2e, 0x63, 0x6f, 0x6d};
    [commands appendBytes:qrcodeByteBuffer length:sizeof(qrcodeByteBuffer)]; // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendData:[@"\n\n\n\n" dataUsingEncoding:ENCODING]];
    
    NSData *data = [NSData dataWithData:commands];
    
    return data;
}

/**
 *  This function create the Kanji sample receipt data (2inch)
 */
+ (NSData *)japanese2inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
                   length:sizeof("\x1b\x40") - 1];    // Initialization
    
    [commands appendBytes:"\x1d\x57\x80\x01"
                   length:sizeof("\x1d\x57\x80\x01") - 1];    // 印字領域設定（58mm用紙）
    
    [commands appendBytes:"\x1c\x43\x01"
                   length:sizeof("\x1c\x43\x01") - 1];    // 漢字モード設定
    
    [commands appendBytes:"\x1b\x61\x31"
                   length:sizeof("\x1b\x61\x31") - 1];    // 中央揃え設定
    
    [commands appendBytes:"\x1b\x21\x22"
                   length:sizeof("\x1b\x21\x22") - 1];    // 文字縦拡大設定
    
    [commands appendBytes:"\x1b\x45\x31"
                   length:sizeof("\x1b\x45\x31") - 1];    // 強調印字設定
    
    [commands appendData:[@"スター電機\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x21\x11"
                   length:sizeof("\x1b\x21\x11") - 1];    // 文字縦拡大設定
    
    [commands appendData:[@"修理報告書　兼領収書\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x21\x00"
                   length:sizeof("\x1b\x21\x00") - 1];    // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x45\x00"
                   length:sizeof("\x1b\x45\x00") - 1];    // 強調印字解除
    
    [commands appendData:[@"--------------------------------\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];    // 左揃え設定
    
    [commands appendData:[@"発行日時：YYYY年MM月DD日HH時MM分" "\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"TEL：054-347-XXXX\n\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x74\x01"
                   length:sizeof("\x1b\x74\x01") - 1];    // 文字コード設定（ｶﾀｶﾅ）
    
    [commands appendData:[@"          ｲｹﾆｼ  ｼｽﾞｺ  ｻﾏ\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1c\x43\x01"
                   length:sizeof("\x1c\x43\x01") - 1];    // 漢字モード設定
    
    [commands appendBytes:"\x1b\x52\x08"
                   length:sizeof("\x1b\x52\x08") - 1];    // 国際文字
    
    [commands appendData:[@"　お名前：池西　静子　様\n"
                           "　御住所：静岡市清水区七ツ新屋\n"
                           "　　　　　５３６番地\n"
                           "　伝票番号：No.12345-67890\n\n"
                           "　この度は修理をご用命頂き有難うございます。今後も故障など発生した場合はお気軽にご連絡ください。\n\n"
                           "品名／型名　数量　　金額　 備考\n"
                           "--------------------------------\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"制御基板　　  1　　10,000　配達\n"
                           "操作スイッチ  1　   3,800　配達\n"
                           "パネル　　　  1     2,000　配達\n"
                           "技術料　　　　1　　15,000\n"
                           "出張費用　　  1　   5,000\n"
                           "--------------------------------\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"\n"
                           "                小計   \\ 35,800\n"
                           "                内税   \\  1,790\n"
                           "                合計   \\ 37,590\n\n"
                           "　お問合わせ番号　　12345-67890\n\n\n\n" dataUsingEncoding:NSShiftJISStringEncoding]];

    return commands;
}

/**
 *  This function create the Kanji sample receipt data (3inch)
 */
+ (NSData *)japanese3inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
            length:sizeof("\x1b\x40") - 1];    // Initialization50
    
    [commands appendBytes:"\x1c\x43\x01"
            length:sizeof("\x1c\x43\x01") - 1];    // 漢字モード設定
    
    [commands appendBytes:"\x1b\x61\x31"
            length:sizeof("\x1b\x61\x31") - 1];    // 中央揃え設定
    
    [commands appendBytes:"\x1b\x21\x22"
            length:sizeof("\x1b\x21\x22") - 1];    // 文字縦拡大設定
    
    [commands appendBytes:"\x1b\x45\x31"
            length:sizeof("\x1b\x45\x31") - 1];    // 強調印字設定
    
    [commands appendData:[@"スター電機\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x21\x11"
            length:sizeof("\x1b\x21\x11") - 1];    // 文字縦拡大設定
    
    [commands appendData:[@"修理報告書　兼領収書\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x21\x00"
            length:sizeof("\x1b\x21\x00") - 1];    // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x45\x00"
            length:sizeof("\x1b\x45\x00") - 1];    // 強調印字解除
    
    [commands appendData:[@"------------------------------------------------\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x61\x30"
            length:sizeof("\x1b\x61\x30") - 1];    // 左揃え設定
    
    [commands appendData:[@"発行日時：YYYY年MM月DD日HH時MM分" "\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"TEL：054-347-XXXX\n\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x74\x01"
            length:sizeof("\x1b\x74\x01") - 1];    // 文字コード設定（ｶﾀｶﾅ）
    
    [commands appendData:[@"          ｲｹﾆｼ  ｼｽﾞｺ  ｻﾏ\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1c\x43\x01"
            length:sizeof("\x1c\x43\x01") - 1];    // 漢字モード設定
    
    [commands appendBytes:"\x1b\x52\x08"
                   length:sizeof("\x1b\x52\x08") - 1];    // 国際文字
    
    [commands appendData:[@"　お名前：池西　静子　様\n"
                           "　御住所：静岡市清水区七ツ新屋\n"
                           "　　　　　５３６番地\n"
                           "　伝票番号：No.12345-67890\n\n"
                           "　この度は修理をご用命頂き有難うございます。今後も故障など発生した場合はお気軽にご連絡ください。\n\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"品名／型名　          数量      金額　   備考\n"
                           "------------------------------------------------\n"
                           "制御基板　          　  1　　  10,000    配達\n"
                           "操作スイッチ            1　     3,800　  配達\n"
                           "パネル　　          　  1       2,000　  配達\n"
                           "技術料　          　　　1      15,000\n"
                           "出張費用　　            1　     5,000\n"
                           "------------------------------------------------\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"\n"
                           "　　　　　　　       　  　     小計 \\ 35,800\n"
                           "　　　　　　 　　  　      　   内税 \\  1,790\n"
                           "　　　　　　 　　   　　        合計 \\ 37,590\n\n"
                           "　お問合わせ番号　　12345-67890\n\n\n\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];

    return commands;
}

/**
 *  This function create the Kanji sample receipt data (4inch)
 */
+ (NSData *)japanese4inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
            length:sizeof("\x1b\x40") - 1];    // Initialization
    
    [commands appendBytes:"\x1c\x43\x01"
            length:sizeof("\x1c\x43\x01") - 1];    // 漢字モード設定
    
    [commands appendBytes:"\x1b\x61\x31"
            length:sizeof("\x1b\x61\x31") - 1];    // 中央揃え設定
    
    [commands appendBytes:"\x1b\x21\x22"
            length:sizeof("\x1b\x21\x22") - 1];    // 文字縦拡大設定
    
    [commands appendBytes:"\x1b\x45\x31"
            length:sizeof("\x1b\x45\x31") - 1];    // 強調印字設定
    
    [commands appendData:[@"スター電機\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x21\x11"
            length:sizeof("\x1b\x21\x11") - 1];    // 文字縦拡大設定
    
    [commands appendData:[@"修理報告書　兼領収書\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x21\x00"
            length:sizeof("\x1b\x21\x00") - 1];    // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x45\x00"
            length:sizeof("\x1b\x45\x00") - 1];    // 強調印字解除
    
    [commands appendData:[@"---------------------------------------------------------------------\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x61\x30"
            length:sizeof("\x1b\x61\x30") - 1];    // 左揃え設定
    
    [commands appendData:[@"発行日時：YYYY年MM月DD日HH時MM分" "\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"TEL：054-347-XXXX\n\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x74\x01"
            length:sizeof("\x1b\x74\x01") - 1];    // 文字コード設定（ｶﾀｶﾅ）
    
    [commands appendData:[@"          ｲｹﾆｼ  ｼｽﾞｺ  ｻﾏ\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1c\x43\x01"
            length:sizeof("\x1c\x43\x01") - 1];    // 漢字モード設定
    
    [commands appendBytes:"\x1b\x52\x08"
                   length:sizeof("\x1b\x52\x08") - 1];    // 国際文字
    
    [commands appendData:[@"　お名前：池西　静子　様\n"
                           "　御住所：静岡市清水区七ツ新屋\n"
                           "　　　　　５３６番地\n"
                           "　伝票番号：No.12345-67890\n\n"
                           "　この度は修理をご用命頂き有難うございます。今後も故障など発生した場合はお気軽にご連絡ください。\n\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"品名／型名　                 数量             金額　          備考\n"
                           "---------------------------------------------------------------------\n"
                           "制御基板　                 　  1       　　  10,000           配達\n"
                           "操作スイッチ                   1　            3,800       　  配達\n"
                           "パネル       　　          　  1              2,000       　 配達\n"
                           "技術料　                 　　　1             15,000\n"
                           "出張費用       　　            1　            5,000\n"
                           "---------------------------------------------------------------------\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"\n"
                           "                     　　　　　　　       　  　     小計 \\ 35,800\n"
                           "                     　　　　　　 　　  　      　   内税 \\  1,790\n"
                           "                     　　　　　　 　　   　　        合計 \\ 37,590\n\n"
                           "　お問合わせ番号　　12345-67890\n\n\n\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];
    
    return commands;
}

/**
 *  This function create the Traditional Chinese sample receipt data (2inch)
 */
+ (NSData *)traditionalChinese2inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
                   length:sizeof("\x1b\x40") - 1];            // 初期化
 
    [commands appendBytes:"\x1c\x43\x01"
                   length:sizeof("\x1c\x43\x01") - 1];        // 漢字モード設定
    
    [commands appendBytes:"\x1b\x61\x31"
                   length:sizeof("\x1b\x61\x31") - 1];        // 中央揃え設定
    
    [commands appendBytes:"\x1b\x21\x32"
                   length:sizeof("\x1b\x21\x32") - 1];        // 文字縦拡大設定
    
    [commands appendBytes:"\x1b\x45\x31"
                   length:sizeof("\x1b\x45\x31") - 1];        // 強調印字設定
    
    [commands appendData:[@"Star Micronics\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x21\x00"
                   length:sizeof("\x1b\x21\x00") - 1];        // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x45\x00"
                   length:sizeof("\x1b\x45\x00") - 1];        // 強調印字解除
    
    [commands appendData:[@"--------------------------------\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x21\x33"
                   length:sizeof("\x1b\x21\x33") - 1];        // 文字縦拡大設定
    
    [commands appendData:[@"電子發票證明聯\n"
                          "103年01-02月\n"
                          "EV-99999999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x21\x00"
                   length:sizeof("\x1b\x21\x00") - 1];        // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];        // 左揃え設定

    [commands appendData:[@"2014/01/15 13:00\n"
                          "隨機碼 : 9999    總計 : 999\n"
                          "賣方 : 99999999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];

    // 1D barcode example
    [commands appendBytes:"\x1d\x77\x02"
                   length:sizeof("\x1d\x77\x02") - 1]; // for 1D Code39 Barcode GS w n
    [commands appendBytes:"\x1d\x68\x64"
                   length:sizeof("\x1d\x68\x64") - 1]; // for 1D Code39 Barcode GS h n
    [commands appendBytes:"\x1d\x48\x00"
                   length:sizeof("\x1d\x48\x00") - 1]; // for 1D Code39 Barcode GS H n
    [commands appendBytes:"\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39"
                   length:sizeof("\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];

    // [commands appendBytes:"\x1b\x61\x31"
    //               length:sizeof("\x1b\x61\x31") - 1];        // 中央揃え設定
    
    // QR Code : GS z n + ESC Z m a k nL nH d1..dk
    [commands appendBytes:"\x1d\x5a\x02\x1b\x5a\x00\x51\x06\x23\x00\x68\x74\x74\x70\x3a\x2f\x2f\x77\x77\x77\x2e\x73\x74\x61\x72\x2d\x6d\x2e\x6a\x70\x2f\x65\x6e\x67\x2f\x69\x6e\x64\x65\x78\x2e\x68\x74\x6d\x6c"
                   length:sizeof("\x1d\x5a\x02\x1b\x5a\x00\x51\x06\x23\x00\x68\x74\x74\x70\x3a\x2f\x2f\x77\x77\x77\x2e\x73\x74\x61\x72\x2d\x6d\x2e\x6a\x70\x2f\x65\x6e\x67\x2f\x69\x6e\x64\x65\x78\x2e\x68\x74\x6d\x6c") - 1];    // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];

    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];        // 左揃え設定
    
    [commands appendData:[@"商品退換請持本聯及銷貨明細表。\n"
                           "9999999-9999999 999999-999999\n\n\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x61\x31"
                   length:sizeof("\x1b\x61\x31") - 1];        // 中央揃え設定
    
    [commands appendData:[@"銷貨明細表 　(銷售)\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x61\x32"
                   length:sizeof("\x1b\x61\x32") - 1];        // 右揃え設定
    
    [commands appendData:[@"2014-01-15 13:00:02\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];        // 左揃え設定
    
    [commands appendData:[@"\n"
                           "烏龍袋茶2g20入      55 x2 110TX\n"
                           "茉莉烏龍茶2g20入    55 x2 110TX\n"
                           "天仁觀音茶2g*20     55 x2 110TX\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x31"
                   length:sizeof("\x1b\x45\x31") - 1];        // 強調印字設定
    
    [commands appendData:[@"   小　 計 :          330\n"
                           "   總   計 :          330\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x30"
                   length:sizeof("\x1b\x45\x30") - 1];        // 強調印字解除
    
    [commands appendData:[@"--------------------------------\n"
                           "現 金                 400\n"
                           "   找　 零 :           70\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x31"
                   length:sizeof("\x1b\x45\x31") - 1];        // 強調印字設定
    
    [commands appendData:[@" 101 發票金額 :       330\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x30"
                   length:sizeof("\x1b\x45\x30") - 1];        // 強調印字解除
    
    [commands appendData:[@"2014-01-15 13:00\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];

    // 1D barcode example
    [commands appendBytes:"\x1d\x77\x02"
                   length:sizeof("\x1d\x77\x02") - 1]; // for 1D Code39 Barcode GS w n
    [commands appendBytes:"\x1d\x68\x64"
                   length:sizeof("\x1d\x68\x64") - 1]; // for 1D Code39 Barcode GS h n
    [commands appendBytes:"\x1d\x48\x00"
                   length:sizeof("\x1d\x48\x00") - 1]; // for 1D Code39 Barcode GS H n
    [commands appendBytes:"\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39"
                   length:sizeof("\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];

    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];         // 左揃え設定

    [commands appendData:[@"商品退換、\n"
                           "贈品及停車兌換請持本聯。\n"
                           "9999999-9999999 999999-999999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];
    
    return commands;
}

/**
 *  This function create the Traditional Chinese sample receipt data (3inch)
 */
+ (NSData *)traditionalChinese3inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
                   length:sizeof("\x1b\x40") - 1];            // 初期化
 
    [commands appendBytes:"\x1c\x43\x01"
                   length:sizeof("\x1c\x43\x01") - 1];        // 漢字モード設定
    
    [commands appendBytes:"\x1b\x61\x31"
                   length:sizeof("\x1b\x61\x31") - 1];        // 中央揃え設定
    
    [commands appendBytes:"\x1b\x21\x32"
                   length:sizeof("\x1b\x21\x32") - 1];        // 文字縦拡大設定
    
    [commands appendBytes:"\x1b\x45\x31"
                   length:sizeof("\x1b\x45\x31") - 1];        // 強調印字設定
    
    [commands appendData:[@"Star Micronics\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x21\x00"
                   length:sizeof("\x1b\x21\x00") - 1];        // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x45\x00"
                   length:sizeof("\x1b\x45\x00") - 1];        // 強調印字解除
    
    [commands appendData:[@"--------------------------------------------\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x21\x33"
                   length:sizeof("\x1b\x21\x33") - 1];        // 文字縦拡大設定
    
    [commands appendData:[@"電子發票證明聯\n"
                           "103年01-02月\n"
                           "EV-99999999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x21\x00"
                   length:sizeof("\x1b\x21\x00") - 1];        // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];        // 左揃え設定
    
    [commands appendData:[@"2014/01/15 13:00\n"
                           "隨機碼 : 9999    總計 : 999\n"
                           "賣方 : 99999999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
  
    // 1D barcode example
    [commands appendBytes:"\x1d\x77\x02"
                   length:sizeof("\x1d\x77\x02") - 1]; // for 1D Code39 Barcode GS w n
    [commands appendBytes:"\x1d\x68\x64"
                   length:sizeof("\x1d\x68\x64") - 1]; // for 1D Code39 Barcode GS h n
    [commands appendBytes:"\x1d\x48\x00"
                   length:sizeof("\x1d\x48\x00") - 1]; // for 1D Code39 Barcode GS H n
    [commands appendBytes:"\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39"
                   length:sizeof("\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];
    
    // [commands appendBytes:"\x1b\x61\x31"
    //               length:sizeof("\x1b\x61\x31") - 1];        // 中央揃え設定

    // QR Code : GS z n + ESC Z m a k nL nH d1..dk
    [commands appendBytes:"\x1d\x5a\x02\x1b\x5a\x00\x51\x06\x23\x00\x68\x74\x74\x70\x3a\x2f\x2f\x77\x77\x77\x2e\x73\x74\x61\x72\x2d\x6d\x2e\x6a\x70\x2f\x65\x6e\x67\x2f\x69\x6e\x64\x65\x78\x2e\x68\x74\x6d\x6c"
                   length:sizeof("\x1d\x5a\x02\x1b\x5a\x00\x51\x06\x23\x00\x68\x74\x74\x70\x3a\x2f\x2f\x77\x77\x77\x2e\x73\x74\x61\x72\x2d\x6d\x2e\x6a\x70\x2f\x65\x6e\x67\x2f\x69\x6e\x64\x65\x78\x2e\x68\x74\x6d\x6c") - 1];    // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];        // 左揃え設定
    
    [commands appendData:[@"商品退換請持本聯及銷貨明細表。\n"
                           "9999999-9999999 999999-999999 9999\n\n\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x61\x31"
                   length:sizeof("\x1b\x61\x31") - 1];        // 中央揃え設定
    
    [commands appendData:[@"銷貨明細表 　(銷售)\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x61\x32"
                   length:sizeof("\x1b\x61\x32") - 1];        // 右揃え設定
    
    [commands appendData:[@"2014-01-15 13:00:02\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];        // 左揃え設定
    
    [commands appendData:[@"\n"
                           "烏龍袋茶2g20入             55 x2 110TX\n"
                           "茉莉烏龍茶2g20入           55 x2 110TX\n"
                           "天仁觀音茶2g*20            55 x2 110TX\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x31"
                   length:sizeof("\x1b\x45\x31") - 1];        // 強調印字設定
    
    [commands appendData:[@"      小　 計 :              330\n"
                           "      總   計 :              330\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x30"
                   length:sizeof("\x1b\x45\x30") - 1];        // 強調印字解除
    
    [commands appendData:[@"--------------------------------------------\n"
                           "現 金                        400\n"
                           "      找　 零 :               70\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x31"
                   length:sizeof("\x1b\x45\x31") - 1];        // 強調印字設定
    
    [commands appendData:[@" 101 發票金額 :              330\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x30"
                   length:sizeof("\x1b\x45\x30") - 1];        // 強調印字解除
    
    [commands appendData:[@"2014-01-15 13:00\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    
    // 1D barcode example
    [commands appendBytes:"\x1d\x77\x02"
                   length:sizeof("\x1d\x77\x02") - 1]; // for 1D Code39 Barcode GS w n
    [commands appendBytes:"\x1d\x68\x64"
                   length:sizeof("\x1d\x68\x64") - 1]; // for 1D Code39 Barcode GS h n
    [commands appendBytes:"\x1d\x48\x00"
                   length:sizeof("\x1d\x48\x00") - 1]; // for 1D Code39 Barcode GS H n
    [commands appendBytes:"\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39"
                   length:sizeof("\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];         // 左揃え設定
    
    [commands appendData:[@"商品退換、贈品及停車兌換請持本聯。\n"
                          "9999999-9999999 999999-999999 9999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];
    
    return commands;
}

/**
 *  This function create the Traditional Chinese sample receipt data (4inch)
 */
+ (NSData *)traditionalChinese4inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
                   length:sizeof("\x1b\x40") - 1];            // 初期化
    
    [commands appendBytes:"\x1c\x43\x01"
                   length:sizeof("\x1c\x43\x01") - 1];        // 漢字モード設定
    
    [commands appendBytes:"\x1b\x61\x31"
                   length:sizeof("\x1b\x61\x31") - 1];        // 中央揃え設定
    
    [commands appendBytes:"\x1b\x21\x32"
                   length:sizeof("\x1b\x21\x32") - 1];        // 文字縦拡大設定
    
    [commands appendBytes:"\x1b\x45\x31"
                   length:sizeof("\x1b\x45\x31") - 1];        // 強調印字設定
    
    [commands appendData:[@"Star Micronics\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x21\x00"
                   length:sizeof("\x1b\x21\x00") - 1];        // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x45\x00"
                   length:sizeof("\x1b\x45\x00") - 1];        // 強調印字解除
    
    [commands appendData:[@"---------------------------------------------------------------------\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x21\x33"
                   length:sizeof("\x1b\x21\x33") - 1];        // 文字縦拡大設定
    
    [commands appendData:[@"電子發票證明聯\n"
                          "103年01-02月\n"
                          "EV-99999999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x21\x00"
                   length:sizeof("\x1b\x21\x00") - 1];        // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];        // 左揃え設定
    
    [commands appendData:[@"2014/01/15 13:00\n"
                          "隨機碼 : 9999    總計 : 999\n"
                          "賣方 : 99999999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    // 1D barcode example
    [commands appendBytes:"\x1d\x77\x02"
                   length:sizeof("\x1d\x77\x02") - 1]; // for 1D Code39 Barcode GS w n
    [commands appendBytes:"\x1d\x68\x64"
                   length:sizeof("\x1d\x68\x64") - 1]; // for 1D Code39 Barcode GS h n
    [commands appendBytes:"\x1d\x48\x00"
                   length:sizeof("\x1d\x48\x00") - 1]; // for 1D Code39 Barcode GS H n
    [commands appendBytes:"\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39"
                   length:sizeof("\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];
    
    // [commands appendBytes:"\x1b\x61\x31"
    //                length:sizeof("\x1b\x61\x31") - 1];        // 中央揃え設定
    
    // QR Code : GS z n + ESC Z m a k nL nH d1..dk
    [commands appendBytes:"\x1d\x5a\x02\x1b\x5a\x00\x51\x06\x23\x00\x68\x74\x74\x70\x3a\x2f\x2f\x77\x77\x77\x2e\x73\x74\x61\x72\x2d\x6d\x2e\x6a\x70\x2f\x65\x6e\x67\x2f\x69\x6e\x64\x65\x78\x2e\x68\x74\x6d\x6c"
                   length:sizeof("\x1d\x5a\x02\x1b\x5a\x00\x51\x06\x23\x00\x68\x74\x74\x70\x3a\x2f\x2f\x77\x77\x77\x2e\x73\x74\x61\x72\x2d\x6d\x2e\x6a\x70\x2f\x65\x6e\x67\x2f\x69\x6e\x64\x65\x78\x2e\x68\x74\x6d\x6c") - 1];    // QR Code (View QR 2D Barcode code for better explanation)
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];        // 左揃え設定
    
    [commands appendData:[@"商品退換請持本聯及銷貨明細表。\n"
                          "9999999-9999999 999999-999999 9999\n\n\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x61\x31"
                   length:sizeof("\x1b\x61\x31") - 1];        // 中央揃え設定
    
    [commands appendData:[@"銷貨明細表 　(銷售)\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x61\x32"
                   length:sizeof("\x1b\x61\x32") - 1];        // 右揃え設定
    
    [commands appendData:[@"2014-01-15 13:00:02\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];        // 左揃え設定
    
    [commands appendData:[@"\n"
                           "烏龍袋茶2g20入                             55 x2         110TX\n"
                           "茉莉烏龍茶2g20入                           55 x2         110TX\n"
                           "天仁觀音茶2g*20                            55 x2         110TX\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x31"
                   length:sizeof("\x1b\x45\x31") - 1];        // 強調印字設定
    
    [commands appendData:[@"      小　 計 :                              330\n"
                           "      總   計 :                              330\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x30"
                   length:sizeof("\x1b\x45\x30") - 1];        // 強調印字解除
    
    [commands appendData:[@"---------------------------------------------------------------------\n"
                           "現 金                                        400\n"
                           "      找　 零 :                               70\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x31"
                   length:sizeof("\x1b\x45\x31") - 1];        // 強調印字設定
    
    [commands appendData:[@" 101 發票金額 :                              330\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45\x30"
                   length:sizeof("\x1b\x45\x30") - 1];        // 強調印字解除
    
    [commands appendData:[@"2014-01-15 13:00\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    
    // 1D barcode example
    [commands appendBytes:"\x1d\x77\x02"
                   length:sizeof("\x1d\x77\x02") - 1]; // for 1D Code39 Barcode GS w n
    [commands appendBytes:"\x1d\x68\x64"
                   length:sizeof("\x1d\x68\x64") - 1]; // for 1D Code39 Barcode GS h n
    [commands appendBytes:"\x1d\x48\x00"
                   length:sizeof("\x1d\x48\x00") - 1]; // for 1D Code39 Barcode GS H n
    [commands appendBytes:"\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39"
                   length:sizeof("\x1d\x6b\x45\x0b\x39\x39\x39\x39\x39\x39\x39\x37\x38\x39\x39") - 1];    // for 1D Code39 Barcode
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];
    
    [commands appendBytes:"\x1b\x61\x30"
                   length:sizeof("\x1b\x61\x30") - 1];         // 左揃え設定
    
    [commands appendData:[@"商品退換、贈品及停車兌換請持本聯。\n"
                          "9999999-9999999 999999-999999 9999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\n\n"
                   length:sizeof("\n\n") - 1];
  
    return commands;
}

#pragma mark Sample Receipt + Open Cash Drawer

+ (void)PrintSampleReceiptWithPortname:(NSString *)portName portSettings:(NSString *)portSettings paperWidth:(SMPaperWidth)paperWidth errorMessage:(NSMutableString *)message
{

    UIAlertView *alert1 = [[UIAlertView alloc] initWithTitle:@"SMPaperWidth3inch"
                                                     message:@""
                                                    delegate:nil
                                           cancelButtonTitle:@"OK"
                                           otherButtonTitles:nil];
    NSData *commands = nil;
    
    switch (paperWidth) {
        case SMPaperWidth2inch:
            commands = [self english2inchSampleReceipt];
            break;
            
        case SMPaperWidth3inch:

            [alert1 show];

            commands = [self english3inchSampleReceipt];
            break;
            
        case SMPaperWidth4inch:
            commands = [self english4inchSampleReceipt];
            break;
            
        default:
            return;
    }
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000 errorMessage:message];
    
    //[commands release];
}

+ (void)sendCommand:(NSData *)commands
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
            [message appendString:@"Fail to Open Port.\nRefer to \"getPort API\" in the manual."];
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
