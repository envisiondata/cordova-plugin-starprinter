//
//  PrinterFunctions.m
//  IOS_SDK
//
//  Created by Tzvi on 8/2/11.
//  Copyright 2011 - 2013 STAR MICRONICS CO., LTD. All rights reserved.
//

#import "PrinterFunctions.h"
#import <StarIO/SMPort.h>
#import <StarIO/SMBluetoothManager.h>
//#import "RasterDocument.h"
//#import "StarBitmap.h"
#import <sys/time.h>
#import <unistd.h>
//#import "AppDelegate.h"

@implementation PrinterFunctions

#pragma mark Get Firmware Version

/*!
 *  This function shows the printer firmware information
 *
 *  @param  portName        Port name to use for communication
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)showFirmwareVersion:(NSString *)portName portSettings:(NSString *)portSettings
{
    SMPort *starPort = nil;
    NSDictionary *dict = nil;
    
    @try
    {
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
        
    }
    @catch (PortException *exception)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printer Error"
                                                        message:@"Get firmware information failed"
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

#pragma mark Check whether supporting bluetooth setting

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

#pragma mark Open Cash Drawer

/*!
 *  This function opens the cash drawer connected to the printer
 *  This function just send the byte 0x07 to the printer which is the open Cash Drawer command
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)OpenCashDrawerWithPortname:(NSString *)portName portSettings:(NSString *)portSettings drawerNumber:(NSUInteger)drawerNumber
{
    unsigned char opencashdrawer_command = 0x00;
    
    if (drawerNumber == 1) {
        opencashdrawer_command = 0x07; // BEL
    }
    else if (drawerNumber == 2) {
        opencashdrawer_command = 0x1a; // SUB
    }
    
    NSData *commands = [NSData dataWithBytes:&opencashdrawer_command length:1];
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];
}


#pragma mark Check Status

/*!
 *  This function checks the status of the printer.
 *  The check status function can be used for both portable and non portable printers.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *
 */
+ (void)CheckStatusWithPortname:(NSString *)portName portSettings:(NSString *)portSettings sensorSetting:(SensorActive)sensorActiveSetting
{
    SMPort *starPort = nil;
    @try
    {
        starPort = [SMPort getPort:portName :portSettings :10000];
        if (starPort == nil) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Fail to Open Port.\nRefer to \"getPort API\" in the manual."
                                                            message:@""
                                                           delegate:nil 
                                                  cancelButtonTitle:@"OK" 
                                                  otherButtonTitles:nil];
            [alert show];
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

        NSString *drawerStatus;
        if (sensorActiveSetting == SensorActiveHigh)
        {
            drawerStatus = (status.compulsionSwitch == SM_TRUE) ? @"Open" : @"Close";
            message = [message stringByAppendingFormat:@"\nCash Drawer: %@", drawerStatus];
        }
        else if (sensorActiveSetting == SensorActiveLow)
        {
            drawerStatus = (status.compulsionSwitch == SM_FALSE) ? @"Open" : @"Close";
            message = [message stringByAppendingFormat:@"\nCash Drawer: %@", drawerStatus];
        }
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Printer Status"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];

        [alert show];
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

#pragma mark 1D Barcode

/**
 *  This function is used to print bar codes in the 39 format
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  barcodeData     These are the characters that will be printed in the bar code. The characters available for
 *                          this bar code are listed in section 3-43 (Rev. 1.12).
 *  @param  barcodeDataSize This is the number of characters in the barcode.  This should be the size of the preceding
 *                          parameter
 *  @param  option          This tell the printer weather put characters under the printed bar code or not.  This may
 *                          also be used to line feed after the bar code is printed.
 *  @param  height          The height of the bar code.  This is measured in pixels
 *  @param  width           The Narrow wide width of the bar code.  This value should be between 1 to 9.  See section
 *                          3-42 (Rev. 1.12) for more information on the values.
 */
+ (void)PrintCode39WithPortname:(NSString*)portName portSettings:(NSString*)portSettings barcodeData:(unsigned char *)barcodeData barcodeDataSize:(unsigned int)barcodeDataSize barcodeOptions:(BarCodeOptions)option height:(unsigned char)height narrowWide:(NarrowWide)width
{
    unsigned char n1 = 0x34;
    unsigned char n2 = 0;
    switch (option) {
        case No_Added_Characters_With_Line_Feed:
            n2 = 49;
            break;
        case Adds_Characters_With_Line_Feed:
            n2 = 50;
            break;
        case No_Added_Characters_Without_Line_Feed:
            n2 = 51;
            break;
        case Adds_Characters_Without_Line_Feed:
            n2 = 52;
            break;
    }
    unsigned char n3 = 0;
    switch (width)
    {
        case NarrowWide_2_6:
            n3 = 49;
            break;
        case NarrowWide_3_9:
            n3 = 50;
            break;
        case NarrowWide_4_12:
            n3 = 51;
            break;
        case NarrowWide_2_5:
            n3 = 52;
            break;
        case NarrowWide_3_8:
            n3 = 53;
            break;
        case NarrowWide_4_10:
            n3 = 54;
            break;
        case NarrowWide_2_4:
            n3 = 55;
            break;
        case NarrowWide_3_6:
            n3 = 56;
            break;
        case NarrowWide_4_8:
            n3 = 57;
            break;
    }
    unsigned char n4 = height;
    
    unsigned char *command = (unsigned char*)malloc(6 + barcodeDataSize + 1);
    command[0] = 0x1b;
    command[1] = 0x62;
    command[2] = n1;
    command[3] = n2;
    command[4] = n3;
    command[5] = n4;
    for (int index = 0; index < barcodeDataSize; index++)
    {
        command[index + 6] = barcodeData[index];
    }
    command[6 + barcodeDataSize] = 0x1e;
    
    int commandSize = 6 + barcodeDataSize + 1;
    
    NSData *dataToSentToPrinter = [[NSData alloc] initWithBytes:command length:commandSize];
    
    [self sendCommand:dataToSentToPrinter portName:portName portSettings:portSettings timeoutMillis:10000];
    
    free(command);
}

/**
 *  This function is used to print bar codes in the 93 format
 *
 *  @param   portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                           or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 * @param   barcodeData     These are the characters that will be printed in the bar code. The characters available for
 *                          this bar code are listed in section 3-43 (Rev. 1.12).
 * @param   barcodeDataSize This is the number of characters in the barcode.  This should be the size of the preceding
 *                          parameter
 * @param   option          This tell the printer weather put characters under the printed bar code or not. This may
 *                          also be used to line feed after the bar code is printed.
 * @param   height          The height of the bar code.  This is measured in pixels
 * @param   width           This is the number of dots per module.  This value should be between 1 to 3.  See section
 *                          3-42 (Rev. 1.12) for more information on the values.
 */
+ (void)PrintCode93WithPortname:(NSString*)portName portSettings:(NSString*)portSettings barcodeData: (unsigned char *)barcodeData barcodeDataSize:(unsigned int)barcodeDataSize barcodeOptions:(BarCodeOptions)option height:(unsigned char)height min_module_dots:(Min_Mod_Size)width
{
    unsigned char n1 = 0x37;
    unsigned char n2 = 0;
    switch (option)
    {
        case No_Added_Characters_With_Line_Feed:
            n2 = 49;
            break;
        case Adds_Characters_With_Line_Feed:
            n2 = 50;
            break;
        case No_Added_Characters_Without_Line_Feed:
            n2 = 51;
            break;
        case Adds_Characters_Without_Line_Feed:
            n2 = 52;
            break;
    }
    unsigned char n3 = 0;
    switch (width)
    {
        case _2_dots:
            n3 = 49;
            break;
        case _3_dots:
            n3 = 50;
            break;
        case _4_dots:
            n3 = 51;
            break;
    }
    unsigned char n4 = height;
    unsigned char *command = (unsigned char*)malloc(6 + barcodeDataSize + 1);
    command[0] = 0x1b;
    command[1] = 0x62;
    command[2] = n1;
    command[3] = n2;
    command[4] = n3;
    command[5] = n4;
    for (int index = 0; index < barcodeDataSize; index++)
    {
        command[index + 6] = barcodeData[index];
    }
    command[6 + barcodeDataSize] = 0x1e;
    
    int commandSize = 6 + barcodeDataSize + 1;
    
    NSData *dataToSentToPrinter = [[NSData alloc] initWithBytes:command length:commandSize];
    
    [self sendCommand:dataToSentToPrinter portName:portName portSettings:portSettings timeoutMillis:10000];
    
    free(command);
}

/**
 * This function is used to print bar codes in the ITF format
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  barcodeData     These are the characters that will be printed in the bar code. The characters available for
 *                          this bar code are listed in section 3-43 (Rev. 1.12).
 *  @param  barcodeDataSize This is the number of characters in the barcode.  This should be the size of the preceding
 *                          parameter
 *  @param  option          This tell the printer weather put characters under the printed bar code or not.  This may
 *                          also be used to line feed after the bar code is printed.
 *  @param  height          The height of the bar code.  This is measured in pixels
 *  @param  width           This is the number of dots per module.  This value should be between 1 to 3.  See section
 *                          3-42 (Rev. 1.12) for more information on the values.
 */
+ (void)PrintCodeITFWithPortname:(NSString*)portName portSettings:(NSString*)portSettings barcodeData:(unsigned char *)barcodeData barcodeDataSize:(unsigned int)barcodeDataSize barcodeOptions:(BarCodeOptions)option height:(unsigned char)height narrowWide:(NarrowWideV2)width
{
    unsigned char n1 = 0x35;
    unsigned char n2 = 0;
    switch (option)
    {
        case No_Added_Characters_With_Line_Feed:
            n2 = 49;
            break;
        case Adds_Characters_With_Line_Feed:
            n2 = 50;
            break;
        case No_Added_Characters_Without_Line_Feed:
            n2 = 51;
            break;
        case Adds_Characters_Without_Line_Feed:
            n2 = 52;
            break;
    }
    unsigned char n3 = 0;
    switch (width)
    {
        case NarrowWideV2_2_5:
            n3 = 49;
            break;
        case NarrowWideV2_4_10:
            n3 = 50;
            break;
        case NarrowWideV2_6_15:
            n3 = 51;
            break;
        case NarrowWideV2_2_4:
            n3 = 52;
            break;
        case NarrowWideV2_4_8:
            n3 = 53;
            break;
        case NarrowWideV2_6_12:
            n3 = 54;
            break;
        case NarrowWideV2_2_6:
            n3 = 55;
            break;
        case NarrowWideV2_3_9:
            n3 = 56;
            break;
        case NarrowWideV2_4_12:
            n3 = 57;
            break;
    }
    
    unsigned char n4 = height;
    unsigned char *command = (unsigned char*)malloc(6 + barcodeDataSize + 1);
    command[0] = 0x1b;
    command[1] = 0x62;
    command[2] = n1;
    command[3] = n2;
    command[4] = n3;
    command[5] = n4;
    for (int index = 0; index < barcodeDataSize; index++)
    {
        command[index + 6] = barcodeData[index];
    }
    command[barcodeDataSize + 6] = 0x1e;
    int commandSize = 6 + barcodeDataSize + 1;
    
    NSData *dataToSentToPrinter = [[NSData alloc] initWithBytes:command length:commandSize];
    
    [self sendCommand:dataToSentToPrinter portName:portName portSettings:portSettings timeoutMillis:10000];
    
    free(command);
}

/**
 * This function is used to print bar codes in the 128 format
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  barcodeData     These are the characters that will be printed in the bar code. The characters available for
 *                          this bar code are listed in section 3-43 (Rev. 1.12).
 *  @param  barcodeDataSize This is the number of characters in the barcode.  This should be the size of the preceding
 *                          parameter
 *  @param  option          This tell the printer weather put characters under the printed bar code or not.  This may
 *                          also be used to line feed after the bar code is printed.
 *  @param  height          The height of the bar code.  This is measured in pixels
 *  @param  width           This is the number of dots per module.  This value should be between 1 to 3.  See section
 *                          3-42 (Rev. 1.12) for more information on the values.
 */
+ (void)PrintCode128WithPortname:(NSString*)portName portSettings:(NSString*)portSettings barcodeData:(unsigned char *)barcodeData barcodeDataSize:(unsigned int)barcodeDataSize barcodeOptions:(BarCodeOptions)option height:(unsigned char)height min_module_dots:(Min_Mod_Size)width
{
    unsigned char n1 = 0x36;
    unsigned char n2 = 0;
    switch (option)
    {
        case No_Added_Characters_With_Line_Feed:
            n2 = 49;
            break;
        case Adds_Characters_With_Line_Feed:
            n2 = 50;
            break;
        case No_Added_Characters_Without_Line_Feed:
            n2 = 51;
            break;
        case Adds_Characters_Without_Line_Feed:
            n2 = 52;
            break;
    }
    unsigned char n3 = 0;
    switch (width)
    {
        case _2_dots:
            n3 = 49;
            break;
        case _3_dots:
            n3 = 50;
            break;
        case _4_dots:
            n3 = 51;
            break;
    }
    unsigned char n4 = height;
    unsigned char *command = (unsigned char*)malloc(6 + barcodeDataSize + 1);
    command[0] = 0x1b;
    command[1] = 0x62;
    command[2] = n1;
    command[3] = n2;
    command[4] = n3;
    command[5] = n4;
    for (int index = 0; index < barcodeDataSize; index++)
    {
        command[index + 6] = barcodeData[index];
    }
    command[barcodeDataSize + 6] = 0x1e;
    int commandSize = 6 + barcodeDataSize + 1;
    
    NSData *dataToSentToPrinter = [[NSData alloc] initWithBytes:command length:commandSize];
    
    [self sendCommand:dataToSentToPrinter portName:portName portSettings:portSettings timeoutMillis:10000];
    
    free(command);
}

#pragma mark 2D Barcode

/**
 * This function is used to print a QR Code on standard star printers
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  correctionLevel The correction level for the QR Code.  The correction level can be 7, 15, 25, or 30.  See
 *                          section 3-129 (Rev. 1.12).
 *  @param  model           The model to use when printing the QR Code. See section 3-129 (Rev. 1.12).
 *  @param  cellSize        The cell size of the QR Code.  This value of this should be between 1 and 8. It is
 *                          recommended that this value be 2 or less.
 *  @param  barCodeData     This is the characters in the QR Code.
 *  @param  barcodeDataSize This is the number of characters that will be written into the QR Code. This is the size of
 *                          the preceding parameter
 */
+ (void)PrintQrcodeWithPortname:(NSString*)portName portSettings:(NSString*)portSettings correctionLevel:(CorrectionLevelOption)correctionLevel model:(Model)model cellSize:(unsigned char)cellSize barcodeData:(unsigned char*)barCodeData barcodeDataSize:(unsigned int)barCodeDataSize
{
    NSMutableData *commands = [[NSMutableData alloc] init];
    
    unsigned char modelCommand[] = {0x1b, 0x1d, 0x79, 0x53, 0x30, 0x00};
    switch(model)
    {
        case Model1:
            modelCommand[5] = 1;
            break;
        case Model2:
            modelCommand[5] = 2;
            break;
    }
    
    [commands appendBytes:modelCommand length:6];
    
    unsigned char correctionLevelCommand[] = {0x1b, 0x1d, 0x79, 0x53, 0x31, 0x00};
    switch (correctionLevel)
    {
        case Low:
            correctionLevelCommand[5] = 0;
            break;
        case Middle:
            correctionLevelCommand[5] = 1;
            break;
        case Q:
            correctionLevelCommand[5] = 2;
            break;
        case High:
            correctionLevelCommand[5] = 3;
            break;
    }
    [commands appendBytes:correctionLevelCommand length:6];
    
    unsigned char cellCodeSize[] = {0x1b, 0x1d, 0x79, 0x53, 0x32, 0x00};
    cellCodeSize[5] = cellSize;
    [commands appendBytes:cellCodeSize length:6];
    
    unsigned char qrcodeStart[] = {0x1b, 0x1d, 0x79, 0x44, 0x31, 0x00};
    [commands appendBytes:qrcodeStart length:6];
    unsigned char qrcodeLow = barCodeDataSize % 256;
    unsigned char qrcodeHigh = barCodeDataSize / 256;
    [commands appendBytes:&qrcodeLow length:1];
    [commands appendBytes:&qrcodeHigh length:1];
    [commands appendBytes:barCodeData length:barCodeDataSize];
    
    unsigned char printQrcodeCommand[] = {0x1b, 0x1d, 0x79, 0x50};
    [commands appendBytes:printQrcodeCommand length:4];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];
    
}

/**
 * This function is used to print a PDF417 bar code in a standard star printer
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>),
 *                          (BT:<iOS Port Name>), or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  limit           Selection of the Method to use so specify the bar code size. This is either 0 or 1. 0 is
 *                          Use Limit method and 1 is Use Fixed method. See section 3-122 of the manual (Rev 1.12).
 *  @param  p1              The vertical proportion to use.  The value changes with the limit select.  See section
 *                          3-122 of the manual (Rev 1.12).
 *  @param  p2              The horizontal proportion to use.  The value changes with the limit select.  See section
 *                          3-122 of the manual (Rev 1.12).
 *  @param  securityLevel   This represents how well the bar code can be recovered if it is damaged. This value
 *                          should be 0 to 8.
 *  @param  xDirection      Specifies the X direction size. This value should be from 1 to 10. It is recommended
 *                          that the value be 2 or less.
 *  @param  aspectRatio     Specifies the ratio of the PDF417.  This values should be from 1 to 10.  It is
 *                          recommended that this value be 2 or less.
 *  @param  barcodeData     Specifies the characters in the PDF417 bar code.
 *  @param  barcodeDataSize Specifies the amount of characters to put in the barcode. This should be the size of the
 *                          preceding parameter.
 */
+ (void)PrintPDF417CodeWithPortname:(NSString *)portName portSettings:(NSString *)portSettings limit:(Limit)limit p1:(unsigned char)p1 p2:(unsigned char)p2 securityLevel:(unsigned char)securityLevel xDirection:(unsigned char)xDirection aspectRatio:(unsigned char)aspectRatio barcodeData:(unsigned char[])barcodeData barcodeDataSize:(unsigned int)barcodeDataSize
{
    NSMutableData *commands = [[NSMutableData alloc] init];
    
    unsigned char setBarCodeSize[] = {0x1b, 0x1d, 0x78, 0x53, 0x30, 0x00, 0x00, 0x00};
    switch (limit)
    {
        case USE_LIMITS:
            setBarCodeSize[5] = 0;
            break;
        case USE_FIXED:
            setBarCodeSize[5] = 1;
            break;
    }
    setBarCodeSize[6] = p1;
    setBarCodeSize[7] = p2;
    
    [commands appendBytes:setBarCodeSize length:8];
    
    unsigned char setSecurityLevel[] = {0x1b, 0x1d, 0x78, 0x53, 0x31, 0x00};
    setSecurityLevel[5] = securityLevel;
    [commands appendBytes:setSecurityLevel length:6];
    
    unsigned char setXDirections[] = {0x1b, 0x1d, 0x78, 0x53, 0x32, 0x00};
    setXDirections[5] = xDirection;
    [commands appendBytes:setXDirections length:6];
    
    unsigned char setAspectRatio[] = {0x1b, 0x1d, 0x78, 0x53, 0x33, 0x00};
    setAspectRatio[5] = aspectRatio;
    [commands appendBytes:setAspectRatio length:6];
    
    unsigned char *setBarcodeData = (unsigned char*)malloc(6 + barcodeDataSize);
    setBarcodeData[0] = 0x1b;
    setBarcodeData[1] = 0x1d;
    setBarcodeData[2] = 0x78;
    setBarcodeData[3] = 0x44;
    setBarcodeData[4] = barcodeDataSize % 256;
    setBarcodeData[5] = barcodeDataSize / 256;
    for (int index = 0; index < barcodeDataSize; index++)
    {
        setBarcodeData[index + 6] = barcodeData[index];
    }
    [commands appendBytes:setBarcodeData length:6 + barcodeDataSize];
    free(setBarcodeData);
    
    unsigned char printBarcode[] = {0x1b, 0x1d, 0x78, 0x50};
    [commands appendBytes:printBarcode length:4];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];
    
}

#pragma mark Cut

/**
 *  This function is intended to show how to get a legacy printer to cut the paper
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  cuttype         The cut type to perform, the cut types are full cut, full cut with feed, partial cut, and
 *                          partial cut with feed
 */
+ (void)PerformCutWithPortname:(NSString *)portName portSettings:(NSString*)portSettings cutType:(CutType)cuttype
{
    unsigned char autocutCommand[] = {0x1b, 0x64, 0x00};
    switch (cuttype)
    {
        case FULL_CUT:
            autocutCommand[2] = 48;
            break;
        case PARTIAL_CUT:
            autocutCommand[2] = 49;
            break;
        case FULL_CUT_FEED:
            autocutCommand[2] = 50;
            break;
        case PARTIAL_CUT_FEED:
            autocutCommand[2] = 51;
            break;
    }
    
    int commandSize = 3;
    
    NSData *dataToSentToPrinter = [[NSData alloc] initWithBytes:autocutCommand length:commandSize];
    
    [self sendCommand:dataToSentToPrinter portName:portName portSettings:portSettings timeoutMillis:10000];
    
}

#pragma mark Text Formatting

/**
 *  This function prints raw text to the print.  It show how the text can be formated.  For example changing its size.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  slashedZero     boolean variable to tell the printer to weather to put a slash in the zero characters that
 *                          it print
 *  @param  underline       boolean variable that Tells the printer if should underline the text
 *  @param  invertColor     boolean variable that tells the printer if it should invert the text its printing.  All
 *                          White space will become black and the characters will be left white
 *  @param  emphasized      boolean variable that tells the printer if it should emphasize the printed text.  This is
 *                          sort of like bold but not as dark, but darker then regular characters.
 *  @param  upperline       boolean variable that tells the printer if to place a line above the text.  This only
 *                          supported by new printers.
 *  @param  upsideDown      boolean variable that tells the printer if the text should be printed upside-down
 *  @param  heightExpansion This integer tells the printer what multiple the character height should be, this should be
 *                          from 0 to 5 representing multiples from 1 to 6
 *  @param  widthExpansion  This integer tell the printer what multiple the character width should be, this should be
 *                          from 0 to 5 representing multiples from 1 to 6.
 *  @param  leftMargin      The left margin for the text.  Although the max value for this can be 255, the value
 *                          shouldn't get that high or the text could be pushed off the page.
 *  @param  alignment       The alignment of the text. The printers support left, right, and center justification
 *  @param  textData        The text to print
 *  @param  textDataSize    The amount of text to send to the printer
 */
+ (void)PrintTextWithPortname:(NSString *)portName portSettings:(NSString*)portSettings slashedZero:(bool)slashedZero underline:(bool)underline invertColor:(bool)invertColor emphasized:(bool)emphasized upperline:(bool)upperline upsideDown:(bool)upsideDown heightExpansion:(int)heightExpansion widthExpansion:(int)widthExpansion leftMargin:(unsigned char)leftMargin alignment: (Alignment)alignment textData:(unsigned char *)textData textDataSize:(unsigned int)textDataSize
{
    NSMutableData *commands = [[NSMutableData alloc] init];
    
	unsigned char initial[] = {0x1b, 0x40};
	[commands appendBytes:initial length:2];
	
    unsigned char slashedZeroCommand[] = {0x1b, 0x2f, 0x00};
    if (slashedZero)
    {
        slashedZeroCommand[2] = 49;
    }
    else
    {
        slashedZeroCommand[2] = 48;
    }
    [commands appendBytes:slashedZeroCommand length:3];
    
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
    
    unsigned char invertColorCommand[] = {0x1b, 0x00};
    if (invertColor)
    {
        invertColorCommand[1] = 0x34;
    }
    else
    {
        invertColorCommand[1] = 0x35;
    }
    [commands appendBytes:invertColorCommand length:2];
    
    unsigned char emphasizedPrinting[] = {0x1b, 0x00};
    if (emphasized)
    {
        emphasizedPrinting[1] = 69;
    }
    else
    {
        emphasizedPrinting[1] = 70;
    }
    [commands appendBytes:emphasizedPrinting length:2];
    
    unsigned char upperLineCommand[] = {0x1b, 0x5f, 0x00};
    if (upperline)
    {
        upperLineCommand[2] = 49;
    }
    else
    {
        upperLineCommand[2] = 48;
    }
    [commands appendBytes:upperLineCommand length:3];
    
    if (upsideDown)
    {
        unsigned char upsd = 0x0f;
        [commands appendBytes:&upsd length:1];
    }
    else
    {
        unsigned char upsd = 0x12;
        [commands appendBytes:&upsd length:1];
    }
    
    unsigned char characterExpansion[] = {0x1b, 0x69, 0x00, 0x00};
    characterExpansion[2] = heightExpansion + '0';
    characterExpansion[3] = widthExpansion + '0';
    [commands appendBytes:characterExpansion length:4];
    
    unsigned char leftMarginCommand[] = {0x1b, 0x6c, 0x00};
    leftMarginCommand[2] = leftMargin;
    [commands appendBytes:leftMarginCommand length:3];
    
    unsigned char alignmentCommand[] = {0x1b, 0x1d, 0x61, 0x00};
    switch (alignment)
    {
        case Left:
            alignmentCommand[3] = 48;
            break;
        case Center:
            alignmentCommand[3] = 49;
            break;
        case Right:
            alignmentCommand[3] = 50;
            break;
    }
    [commands appendBytes:alignmentCommand length:4];
    
    [commands appendBytes:textData length:textDataSize];
    
    unsigned char lf = 0x0a;
    [commands appendBytes:&lf length:1];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];
    
}

/**
 *  This function prints raw Kanji text to the print.  It show how the text can be formated. For example changing its
 *  size.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  kanjiMode       The segment index of Japanese Kanji mode that Tells the printer to weather Shift-JIS or JIS.
 *  @param  underline       boolean variable that Tells the printer if should underline the text
 *  @param  invertColor     boolean variable that tells the printer if it should invert the text its printing.  All
 *                          White space will become black and the characters will be left white
 *  @param  emphasized      boolean variable that tells the printer if it should emphasize the printed text.  This is
 *                          sort of like bold but not as dark, but darker then regular characters.
 *  @param  upperline       boolean variable that tells the printer if to place a line above the text.  This only
 *                          supported by new printers.
 *  @param  upsideDown      boolean variable that tells the printer if the text should be printed upside-down
 *  @param  heightExpansion This integer tells the printer what multiple the character height should be, this should be
 *                          from 0 to 5 representing multiples from 1 to 6
 *  @param  widthExpansion  This integer tell the printer what multiple the character width should be, this should be
 *                          from 0 to 5 representing multiples from 1 to 6.
 *  @param  leftMargin      The left margin for the text.  Although the max value for this can be 255, the value
 *                          shouldn't get that high or the text could be pushed off the page.
 *  @param  alignment       The alignment of the text. The printers support left, right, and center justification
 *  @param  textData        The text to print
 *  @param  textDataSize    The amount of text to send to the printer
 */
+ (void)PrintKanjiTextWithPortname:(NSString *)portName portSettings:(NSString*)portSettings kanjiMode:(int)kanjiMode underline:(bool)underline invertColor:(bool)invertColor emphasized:(bool)emphasized upperline:(bool)upperline upsideDown:(bool)upsideDown heightExpansion:(int)heightExpansion widthExpansion:(int)widthExpansion leftMargin:(unsigned char)leftMargin alignment:(Alignment)alignment textData:(unsigned char*)textData textDataSize:(unsigned int)textDataSize
{
    NSMutableData *commands = [[NSMutableData alloc] init];

	unsigned char initial[] = {0x1b, 0x40};
	[commands appendBytes:initial length:2];
		
    unsigned char kanjiModeCommand[] = {0x1b, 0x24, 0x00, 0x1b, 0x00};
    if (kanjiMode == 0)	// Shift-JIS
    {
        kanjiModeCommand[2] = 0x01;
        kanjiModeCommand[4] = 0x71;
    }
    else				// JIS
    {
        kanjiModeCommand[2] = 0x00;
        kanjiModeCommand[4] = 0x70;
    }
    [commands appendBytes:kanjiModeCommand length:5];
    
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
    
    unsigned char invertColorCommand[] = {0x1b, 0x00};
    if (invertColor)
    {
        invertColorCommand[1] = 0x34;
    }
    else
    {
        invertColorCommand[1] = 0x35;
    }
    [commands appendBytes:invertColorCommand length:2];
    
    unsigned char emphasizedPrinting[] = {0x1b, 0x00};
    if (emphasized)
    {
        emphasizedPrinting[1] = 69;
    }
    else
    {
        emphasizedPrinting[1] = 70;
    }
    [commands appendBytes:emphasizedPrinting length:2];
    
    unsigned char upperLineCommand[] = {0x1b, 0x5f, 0x00};
    if (upperline)
    {
        upperLineCommand[2] = 49;
    }
    else
    {
        upperLineCommand[2] = 48;
    }
    [commands appendBytes:upperLineCommand length:3];
    
    if (upsideDown)
    {
        unsigned char upsd = 0x0f;
        [commands appendBytes:&upsd length:1];
    }
    else
    {
        unsigned char upsd = 0x12;
        [commands appendBytes:&upsd length:1];
    }
    
    unsigned char characterExpansion[] = {0x1b, 0x69, 0x00, 0x00};
    characterExpansion[2] = heightExpansion + '0';
    characterExpansion[3] = widthExpansion + '0';
    [commands appendBytes:characterExpansion length:4];
    
    unsigned char leftMarginCommand[] = {0x1b, 0x6c, 0x00};
    leftMarginCommand[2] = leftMargin;
    [commands appendBytes:leftMarginCommand length:3];
    
    unsigned char alignmentCommand[] = {0x1b, 0x1d, 0x61, 0x00};
    switch (alignment)
    {
        case Left:
            alignmentCommand[3] = 48;
            break;
        case Center:
            alignmentCommand[3] = 49;
            break;
        case Right:
            alignmentCommand[3] = 50;
            break;
    }
    [commands appendBytes:alignmentCommand length:4];
    
    [commands appendBytes:textData length:textDataSize];
    
    unsigned char lf = 0x0a;
    [commands appendBytes:&lf length:1];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];

}

/**
 *  This function prints raw Simplified Chinese text to the print. It show how the text can be formated. For example
 *  changing its size.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  underline       boolean variable that Tells the printer if should underline the text
 *  @param  invertColor     boolean variable that tells the printer if it should invert the text its printing.  All
 *                          White space will become black and the characters will be left white
 *  @param  emphasized      boolean variable that tells the printer if it should emphasize the printed text.  This is
 *                          sort of like bold but not as dark, but darker then regular characters.
 *  @param  upperline       boolean variable that tells the printer if to place a line above the text.  This only
 *                          supported by new printers.
 *  @param  upsideDown      boolean variable that tells the printer if the text should be printed upside-down
 *  @param  heightExpansion This integer tells the printer what multiple the character height should be, this should be
 *                          from 0 to 5 representing multiples from 1 to 6
 *  @param  widthExpansion  This integer tell the printer what multiple the character width should be, this should be
 *                          from 0 to 5 representing multiples from 1 to 6.
 *  @param  leftMargin      The left margin for the text.  Although the max value for this can be 255, the value
 *                          shouldn't get that high or the text could be pushed off the page.
 *  @param  alignment       The alignment of the text. The printers support left, right, and center justification
 *  @param  textData        The text to print
 *  @param  textDataSize    The amount of text to send to the printer
 */
+ (void)PrintCHSTextWithPortname:(NSString *)portName portSettings:(NSString*)portSettings underline:(bool)underline invertColor:(bool)invertColor emphasized:(bool)emphasized upperline:(bool)upperline upsideDown:(bool)upsideDown heightExpansion:(int)heightExpansion widthExpansion:(int)widthExpansion leftMargin:(unsigned char)leftMargin alignment:(Alignment)alignment textData:(unsigned char*)textData textDataSize:(unsigned int)textDataSize
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
    
    unsigned char invertColorCommand[] = {0x1b, 0x00};
    if (invertColor)
    {
        invertColorCommand[1] = 0x34;
    }
    else
    {
        invertColorCommand[1] = 0x35;
    }
    [commands appendBytes:invertColorCommand length:2];
    
    unsigned char emphasizedPrinting[] = {0x1b, 0x00};
    if (emphasized)
    {
        emphasizedPrinting[1] = 69;
    }
    else
    {
        emphasizedPrinting[1] = 70;
    }
    [commands appendBytes:emphasizedPrinting length:2];
    
    unsigned char upperLineCommand[] = {0x1b, 0x5f, 0x00};
    if (upperline)
    {
        upperLineCommand[2] = 49;
    }
    else
    {
        upperLineCommand[2] = 48;
    }
    [commands appendBytes:upperLineCommand length:3];
    
    if (upsideDown)
    {
        unsigned char upsd = 0x0f;
        [commands appendBytes:&upsd length:1];
    }
    else
    {
        unsigned char upsd = 0x12;
        [commands appendBytes:&upsd length:1];
    }
    
    unsigned char characterExpansion[] = {0x1b, 0x69, 0x00, 0x00};
    characterExpansion[2] = heightExpansion + '0';
    characterExpansion[3] = widthExpansion + '0';
    [commands appendBytes:characterExpansion length:4];
    
    unsigned char leftMarginCommand[] = {0x1b, 0x6c, 0x00};
    leftMarginCommand[2] = leftMargin;
    [commands appendBytes:leftMarginCommand length:3];
    
    unsigned char alignmentCommand[] = {0x1b, 0x1d, 0x61, 0x00};
    switch (alignment)
    {
        case Left:
            alignmentCommand[3] = 48;
            break;
        case Center:
            alignmentCommand[3] = 49;
            break;
        case Right:
            alignmentCommand[3] = 50;
            break;
    }
    [commands appendBytes:alignmentCommand length:4];
    
    [commands appendBytes:textData length:textDataSize];
    
    unsigned char lf = 0x0a;
    [commands appendBytes:&lf length:1];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];
    
}

/**
 *  This function prints raw Traditional Chinese text to the print. It show how the text can be formated.  For example
 *  changing its size.
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  underline       boolean variable that Tells the printer if should underline the text
 *  @param  invertColor     boolean variable that tells the printer if it should invert the text its printing. All White
 *                          space will become black and the characters will be left white
 *  @param  emphasized      boolean variable that tells the printer if it should emphasize the printed text. This is
 *                          sort of like bold but not as dark, but darker then regular characters.
 *  @param  upperline       boolean variable that tells the printer if to place a line above the text.  This only
 *                          supported by new printers.
 *  @param  upsideDown      boolean variable that tells the printer if the text should be printed upside-down
 *  @param  heightExpansion This integer tells the printer what multiple the character height should be, this should be
 *                          from 0 to 5 representing multiples from 1 to 6
 *  @param  widthExpansion  This integer tell the printer what multiple the character width should be, this should be
 *                          from 0 to 5 representing multiples from 1 to 6.
 *  @param  leftMargin      The left margin for the text.  Although the max value for this can be 255, the value
 *                          shouldn't get that high or the text could be pushed off the page.
 *  @param  alignment       The alignment of the text. The printers support left, right, and center justification
 *  @param  textData        The text to print
 *  @param  textDataSize    The amount of text to send to the printer
 */
+ (void)PrintCHTTextWithPortname:(NSString *)portName portSettings:(NSString*)portSettings underline:(bool)underline invertColor:(bool)invertColor emphasized:(bool)emphasized upperline:(bool)upperline upsideDown:(bool)upsideDown heightExpansion:(int)heightExpansion widthExpansion:(int)widthExpansion leftMargin:(unsigned char)leftMargin alignment:(Alignment)alignment textData:(unsigned char*)textData textDataSize:(unsigned int)textDataSize
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
    
    unsigned char invertColorCommand[] = {0x1b, 0x00};
    if (invertColor)
    {
        invertColorCommand[1] = 0x34;
    }
    else
    {
        invertColorCommand[1] = 0x35;
    }
    [commands appendBytes:invertColorCommand length:2];
    
    unsigned char emphasizedPrinting[] = {0x1b, 0x00};
    if (emphasized)
    {
        emphasizedPrinting[1] = 69;
    }
    else
    {
        emphasizedPrinting[1] = 70;
    }
    [commands appendBytes:emphasizedPrinting length:2];
    
    unsigned char upperLineCommand[] = {0x1b, 0x5f, 0x00};
    if (upperline)
    {
        upperLineCommand[2] = 49;
    }
    else
    {
        upperLineCommand[2] = 48;
    }
    [commands appendBytes:upperLineCommand length:3];
    
    if (upsideDown)
    {
        unsigned char upsd = 0x0f;
        [commands appendBytes:&upsd length:1];
    }
    else
    {
        unsigned char upsd = 0x12;
        [commands appendBytes:&upsd length:1];
    }
    
    unsigned char characterExpansion[] = {0x1b, 0x69, 0x00, 0x00};
    characterExpansion[2] = heightExpansion + '0';
    characterExpansion[3] = widthExpansion + '0';
    [commands appendBytes:characterExpansion length:4];
    
    unsigned char leftMarginCommand[] = {0x1b, 0x6c, 0x00};
    leftMarginCommand[2] = leftMargin;
    [commands appendBytes:leftMarginCommand length:3];
    
    unsigned char alignmentCommand[] = {0x1b, 0x1d, 0x61, 0x00};
    switch (alignment)
    {
        case Left:
            alignmentCommand[3] = 48;
            break;
        case Center:
            alignmentCommand[3] = 49;
            break;
        case Right:
            alignmentCommand[3] = 50;
            break;
    }
    [commands appendBytes:alignmentCommand length:4];
    
    [commands appendBytes:textData length:textDataSize];
    
    unsigned char lf = 0x0a;
    [commands appendBytes:&lf length:1];
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000];
    
}

#pragma mark common

/**
 * This function is used to print a UIImage directly to the printer.
 * There are 2 ways a printer can usually print images, one is through raster commands the other is through line mode
 * commands.
 * This function uses raster commands to print an image. Raster is support on the tsp100 and all legacy thermal
 * printers. The line mode printing is not supported by the TSP100 so its not used
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 *  @param  source          The uiimage to convert to star raster data
 *  @param  maxWidth        The maximum with the image to print. This is usually the page with of the printer. If the
 *                          image exceeds the maximum width then the image is scaled down. The ratio is maintained.

+ (void)PrintImageWithPortname:(NSString *)portName
                  portSettings:(NSString*)portSettings
                  imageToPrint:(UIImage*)imageToPrint
                      maxWidth:(int)maxWidth
             compressionEnable:(BOOL)compressionEnable
                withDrawerKick:(BOOL)drawerKick
{
    NSMutableData *commandsToPrint = [NSMutableData new];
    
    SMPrinterType printerType = [AppDelegate parsePortSettings:portSettings];
    StarBitmap *starbitmap = [[StarBitmap alloc] initWithUIImage:imageToPrint :maxWidth :false];
    
    if (printerType == SMPrinterTypeDesktopPrinterStarLine) {
        RasterDocument *rasterDoc = [[RasterDocument alloc] initWithDefaults:RasSpeed_Medium endOfPageBehaviour:RasPageEndMode_FeedAndFullCut endOfDocumentBahaviour:RasPageEndMode_FeedAndFullCut topMargin:RasTopMargin_Standard pageLength:0 leftMargin:0 rightMargin:0];
        
        NSData *shortcommand = [rasterDoc BeginDocumentCommandData];
        [commandsToPrint appendData:shortcommand];
        
        shortcommand = [starbitmap getImageDataForPrinting:compressionEnable];
        [commandsToPrint appendData:shortcommand];
        
        shortcommand = [rasterDoc EndDocumentCommandData];
        [commandsToPrint appendData:shortcommand];
        
        [rasterDoc release];
    } else if (printerType == SMPrinterTypePortablePrinterStarLine) {
        NSData *shortcommand = [starbitmap getGraphicsDataForPrinting:compressionEnable];
        [commandsToPrint appendData:shortcommand];
    } else {
        [commandsToPrint release];
        [starbitmap release];
        return;
    }
    
    [starbitmap release];
    
    // Kick Cash Drawer
    if (drawerKick == YES) {
        [commandsToPrint appendBytes:"\x07"
                              length:sizeof("\x07") - 1];
    }
    
    [self sendCommand:commandsToPrint portName:portName portSettings:portSettings timeoutMillis:10000];

} */

+ (void)sendCommand:(NSData *)commandsToPrint portName:(NSString *)portName portSettings:(NSString *)portSettings timeoutMillis:(u_int32_t)timeoutMillis
{
    int commandSize = (int)commandsToPrint.length;
    unsigned char *dataToSentToPrinter = (unsigned char *)malloc(commandSize);
    [commandsToPrint getBytes:dataToSentToPrinter length:commandSize];
    
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
            return;
        }
        
        StarPrinterStatus_2 status;
        [starPort beginCheckedBlock:&status :2];
        if (status.offline == SM_TRUE) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Printer is offline"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];            return;
        }
        
        struct timeval endTime;
        gettimeofday(&endTime, NULL);
        endTime.tv_sec += 30;
        
        int totalAmountWritten = 0;
        while (totalAmountWritten < commandSize)
        {
            int remaining = commandSize - totalAmountWritten;
            int amountWritten = [starPort writePort:dataToSentToPrinter :totalAmountWritten :remaining];
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
            return;
        }
        
        starPort.endCheckedBlockTimeoutMillis = 30000;
        [starPort endCheckedBlock:&status :2];
        if (status.offline == SM_TRUE) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Printer is offline"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
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
    }
    @finally
    {
        free(dataToSentToPrinter);
        [SMPort releasePort:starPort];
    }
}

#pragma mark Sample Receipt (Line)

/*!
 *  English Sample receipt (2 inch)
 */
+ (NSData *)english2inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x1d\x61\x01"
                   length:sizeof("\x1b\x1d\x61\x01") - 1];    // Alignment (Center)
    
    [commands appendData:[@"Star Clothing Boutique\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"123 Star Road\r\nCity, State 12345\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00"
                   length:sizeof("\x1b\x1d\x61\x00") - 1];    // Alignment (Left)
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00"
                   length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1];    // Set HT
    
    [commands appendData:[@"Date: MM/DD/YYYY" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:" \x09 "
                   length:sizeof(" \x09 ") - 1];
    
    [commands appendData:[@"Time:HH:MM PM\r\n--------------------------------\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x45"
                   length:sizeof("\x1b\x45") - 1];    // Set Bold
    
    [commands appendData:[@"SALE \r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x46"
                   length:sizeof("\x1b\x46") - 1];    // Cancel Bold
    
    [commands appendData:[@"SKU         Description    Total\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [commands appendData:[@"300678566   PLAIN T-SHIRT  10.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [commands appendData:[@"300692003   BLACK DENIM    29.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [commands appendData:[@"300651148   BLUE DENIM     29.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [commands appendData:[@"300642980   STRIPED DRESS  49.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [commands appendData:[@"300638471   BLACK BOOTS    35.99\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Subtotal \x09\x09          156.95\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Tax \x09\x09            0.00\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"--------------------------------\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Total" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x09\x09\x1b\x69\x01\x01"
                   length:sizeof("\x09\x09\x1b\x69\x01\x01") - 1];    // Set Double HW
    
    [commands appendData:[@"$156.95\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x69\x00\x00"
                   length:sizeof("\x1b\x69\x00\x00") - 1];    // Cancel Double HW
    
    [commands appendData:[@"--------------------------------\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Charge\r\n159.95\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Visa XXXX-XXXX-XXXX-0123\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"\x1b\x34Refunds and Exchanges\x1b\x35\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Within " "\x1b\x2d\x01" "30 days\x1b\x2d\x00" " with receipt\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"And tags attached\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01"
                   length:sizeof("\x1b\x1d\x61\x01") - 1];    // Alignment(center)
    
    [commands appendBytes:"\x1b\x62\x06\x02\x02\x20" "12ab34cd56\x1e\r\n"
                   length:sizeof("\x1b\x62\x06\x02\x02\x20" "12ab34cd56\x1e\r\n") - 1];    // PrintBarcode
    
    [commands appendBytes:"\x1b\x64\x02"
                   length:sizeof("\x1b\x64\x02") - 1];    // CutPaper

    return commands;
}

/*!
 *  Sample Receipt 3inch
 */
+ (NSData *)english3inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];

    [commands appendBytes:"\x1b\x1d\x61\x01"
            length:sizeof("\x1b\x1d\x61\x01") - 1];    // center

    [commands appendData:[@"Star Clothing Boutique\r\n" dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendData:[@"123 Star Road\r\nCity, State 12345\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendBytes:"\x1b\x1d\x61\x00"
            length:sizeof("\x1b\x1d\x61\x00") - 1];    // Alignment(left)

    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00"
            length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1];    // SetHT

    [commands appendData:[@"Date: MM/DD/YYYY" dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendBytes:" \x09 "
            length:sizeof(" \x09 ") - 1];

    [commands appendData:[@"Time:HH:MM PM\r\n------------------------------------------------\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x45"
            length:sizeof("\x1b\x45") - 1];    // SetBold

    [commands appendData:[@"SALE \r\n" dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendBytes:"\x1b\x46"
            length:sizeof("\x1b\x46") - 1];    // CancelBold

    [commands appendData:[@"SKU " dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendBytes:"\x09"
            length:sizeof("\x09") - 1];    // HT

    [commands appendData:[@"  Description   \x09         Total\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"300678566 \x09  PLAIN T-SHIRT\x09         10.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"300692003 \x09  BLACK DENIM\x09         29.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"300651148 \x09  BLUE DENIM\x09         29.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"300642980 \x09  STRIPED DRESS\x09         49.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"300638471 \x09  BLACK BOOTS\x09         35.99\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Subtotal \x09\x09        156.95\r\n" dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendData:[@"Tax \x09\x09          0.00\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"------------------------------------------------\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Total" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x09\x09\x1b\x69\x01\x01"
            length:sizeof("\x09\x09\x1b\x69\x01\x01") - 1];    // SetDoubleHW

    [commands appendData:[@"$156.95\r\n" dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendBytes:"\x1b\x69\x00\x00"
            length:sizeof("\x1b\x69\x00\x00") - 1];    // CancelDoubleHW

    [commands appendData:[@"------------------------------------------------\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendData:[@"Charge\r\n159.95\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Visa XXXX-XXXX-XXXX-0123\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];

    [commands appendData:[@"\x1b\x34Refunds and Exchanges\x1b\x35\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Within " "\x1b\x2d\x01" "30 days\x1b\x2d\x00" " with receipt\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"And tags attached\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
     
    [commands appendBytes:"\x1b\x1d\x61\x01"
            length:sizeof("\x1b\x1d\x61\x01") - 1];    // Alignment(center)

    [commands appendBytes:"\x1b\x62\x06\x02\x02\x20" "12ab34cd56\x1e\r\n"
            length:sizeof("\x1b\x62\x06\x02\x02\x20" "12ab34cd56\x1e\r\n") - 1];    // PrintBarcode

    [commands appendBytes:"\x1b\x64\x02"
            length:sizeof("\x1b\x64\x02") - 1];    // CutPaper

    return commands;
}

/**
 *  English Sample Receipt (4inch)
 */
+ (NSData *)english4inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x1d\x61\x01"
            length:sizeof("\x1b\x1d\x61\x01") - 1];    // center
    
    [commands appendData:[@"Star Clothing Boutique\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"123 Star Road\r\nCity, State 12345\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00"
            length:sizeof("\x1b\x1d\x61\x00") - 1];    // Alignment(left)
    
    [commands appendBytes:"\x1b\x44\x02\x1a\x37\x00"
            length:sizeof("\x1b\x44\x02\x1a\x37\x00") - 1];    // SetHT
    
    [commands appendData:[@"Date: MM/DD/YYYY" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:" \x09 "
            length:sizeof(" \x09 ") - 1];
    
    [commands appendData:[@"Time:HH:MM PM\r\n" "---------------------------------------------------------------------\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x45"
            length:sizeof("\x1b\x45") - 1];    // SetBold
    
    [commands appendData:[@"SALE \r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x46"
            length:sizeof("\x1b\x46") - 1];    // CancelBold
    
    [commands appendData:[@"SKU " dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x09"
            length:sizeof("\x09") - 1];    // HT
    
    [commands appendData:[@" Description   \x09         Total\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"300678566 \x09  PLAIN T-SHIRT\x09         10.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"300692003 \x09  BLACK DENIM\x09         29.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"300651148 \x09  BLUE DENIM\x09         29.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"300642980 \x09  STRIPED DRESS\x09         49.99\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"300638471 \x09  BLACK BOOTS\x09         35.99\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Subtotal \x09\x09        156.95\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Tax \x09\x09          0.00\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"---------------------------------------------------------------------\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Total" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x09\x09\x1b\x69\x01\x01"
            length:sizeof("\x09\x09\x1b\x69\x01\x01") - 1];    // SetDoubleHW
    
    [commands appendData:[@"$156.95\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x69\x00\x00"
            length:sizeof("\x1b\x69\x00\x00") - 1];    // CancelDoubleHW
    
    [commands appendData:[@"---------------------------------------------------------------------\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Charge\r\n159.95\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Visa XXXX-XXXX-XXXX-0123\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"\x1b\x34Refunds and Exchanges\x1b\x35\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"Within " "\x1b\x2d\x01" "30 days\x1b\x2d\x00" " with receipt\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendData:[@"And tags attached\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01"
            length:sizeof("\x1b\x1d\x61\x01") - 1];    // Alignment(center)
    
    [commands appendBytes:"\x1b\x62\x06\x02\x02\x20" "12ab34cd56\x1e\r\n"
            length:sizeof("\x1b\x62\x06\x02\x02\x20" "12ab34cd56\x1e\r\n") - 1];    // PrintBarcode
    
    [commands appendBytes:"\x1b\x64\x02"
            length:sizeof("\x1b\x64\x02") - 1];    // CutPaper

    return commands;
}

+ (NSData *)french2inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];

    [commands appendBytes:"\x1b\x1d\x74\x20" length:sizeof("\x1b\x1d\x74\x20") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r// \n" length:sizeof("\x1b\x1c\x70\x01\x00\r// \n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x06\x09\x1b\x69\x01\x01" length:sizeof("\x06\x09\x1b\x69\x01\x01") - 1];

    [commands appendData:[@"\nORANGE\r\n" dataUsingEncoding:ENCODING]];
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"36 AVENUE LA MOTTE PICQUET\r\n\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1]; // Alignment
    
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
                           "CAC IPHONE ORANGE	          0.01€\r\n"
                           "--------------------------------\r\n"
                           "    1 Piéce(s)   Total : 	 19.99€\r\n"
                           "      Mastercard Visa  :  19.99€\r\n\r\n"
                           "Taux TVA    Montant H.T.   T.V.A\r\n"
                           "  20%          16.66€      3.33€\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    [commands appendData:[@"Merci de votre visite et.\r\n"
                           "à bientôt.\r\n"
                           "Conservez votre ticket il\r\n"
                           "vous sera demandé pour \r\n"
                           "tout échange.\r\n" dataUsingEncoding:ENCODING]];
    
    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];
    
    [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut

    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

+ (NSData *)french3inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
     [commands appendBytes:"\x1b\x1d\x74\x20" length:sizeof("\x1b\x1d\x74\x20") - 1]; // Code Page #1252 (Windows Latin-1)
     
     [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
     
     // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
     
     // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r// \n" length:sizeof("\x1b\x1c\x70\x01\x00\r// \n") - 1]; // Stored Logo Printing
    
     // Character expansion
     [commands appendBytes:"\x06\x09\x1b\x69\x01\x01" length:sizeof("\x06\x09\x1b\x69\x01\x01") - 1];


    [commands appendData:[@"\nORANGE\r\n" dataUsingEncoding:ENCODING]];
     [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1]; // Cancel Character Expansion
     
     [commands appendData:[@"36 AVENUE LA MOTTE PICQUET\r\n\r\n" dataUsingEncoding:ENCODING]];
     
     [commands appendBytes:"\x1b\x44\x02\x06\x0a\x10\x14\x1a\x22\x00" length:sizeof("\x1b\x44\x02\x06\x0a\x10\x14\x1a\x22\x00") - 1]; // Set horizontal tab
     
     [commands appendData:[@"------------------------------------------------\r\n"
                            "Date: MM/DD/YYYY    Heure: HH:MM\r\n"
                            "Boutique: OLUA23    Caisse: 0001\r\n"
                            "Conseiller: 002970  Ticket: 3881\r\n"
                            "------------------------------------------------\r\n\r\n" dataUsingEncoding:ENCODING]];
     
     [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1]; // Alignment
     
     [commands appendData:[@"Vous avez été servi par : Souad\r\n\r\n"
                            "CAC IPHONE ORANGE\r\n"
                            "3700615033581 \t1\t X\t 19.99€\t  19.99€\r\n\r\n"
                            "dont contribution environnementale :\r\n"
                            "CAC IPHONE ORANGE\t\t  0.01€\r\n"
                            "------------------------------------------------\r\n"
                            "1 Piéce(s) Total :\t\t\t  19.99€\r\n"
                            "Mastercard Visa  :\t\t\t  19.99€\r\n\r\n" dataUsingEncoding:ENCODING]];
    
     [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
     
     [commands appendData:[@"Taux TVA    Montant H.T.   T.V.A\r\n"
                            "  20%          16.66€      3.33€\r\n"
                            "Merci de votre visite et. à bientôt.\r\n"
                            "Conservez votre ticket il\r\n"
                            "vous sera demandé pour tout échange.\r\n" dataUsingEncoding:ENCODING]];
    
     // 1D barcode example
     [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
     [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];
     
     [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:ENCODING]];
     
     [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut

    return commands;
}

+ (NSData *)french4inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x1d\x74\x20" length:sizeof("\x1b\x1d\x74\x20") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:encoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r// \n" length:sizeof("\x1b\x1c\x70\x01\x00\r// \n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x06\x09\x1b\x69\x01\x01" length:sizeof("\x06\x09\x1b\x69\x01\x01") - 1];

    [commands appendData:[@"\nORANGE\r\n" dataUsingEncoding:ENCODING]];
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"36 AVENUE LA MOTTE PICQUET\r\n\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x44\x02\x06\x0a\x10\x14\x1a\x22\x24\x28\x3c\x00"
                   length:sizeof("\x1b\x44\x02\x06\x0a\x10\x14\x1a\x22\x24\x28\x3c\x00") - 1]; // Set horizontal tab
    
    [commands appendData:[@"---------------------------------------------------------------------\r\n"
                           "Date: MM/DD/YYYY    Heure: HH:MM\r\n"
                           "Boutique: OLUA23    Caisse: 0001\r\n"
                           "Conseiller: 002970  Ticket: 3881\r\n"
                           "---------------------------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1]; // Alignment
    
    [commands appendData:[@"Vous avez été servi par : Souad\r\n\r\n"
                           "CAC IPHONE ORANGE\r\n"
                           "3700615033581 \t1\t X\t 19.99€\t\t\t\t  19.99€\r\n\r\n"
                           "dont contribution environnementale :\r\n"
                           "CAC IPHONE ORANGE\t\t  0.01€\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "1 Piéce(s) Total :\t\t\t\t\t\t  19.99€\r\n"
                           "Mastercard Visa  :\t\t\t\t\t\t  19.99€\r\n\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"Taux TVA    Montant H.T.   T.V.A\r\n"
                           "  20%          16.66€      3.33€\r\n"
                           "Merci de votre visite et. à bientôt.\r\n"
                           "Conservez votre ticket il\r\n"
                           "vous sera demandé pour tout échange.\r\n" dataUsingEncoding:ENCODING]];
    
    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];
    
    [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut

    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

+ (NSData *)portuguese2inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x1d\x74\x20" length:sizeof("\x1b\x1d\x74\x20") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x06\x09\x1b\x69\x01\x00" length:sizeof("\x06\x09\x1b\x69\x01\x00") - 1];

    [commands appendData:[@"\nCOMERCIAL DE ALIMENTOS\r\n"
                           "CARREFOUR LTDA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"Avenida Moyses Roysen,\r\n"
                           "S/N Vila Guilherme\r\n"
                           "Cep: 02049-010 – Sao Paulo – SP\r\n"
                           "CNPJ: 62.545.579/0013-69\r\n"
                           "IE:110.819.138.118\r\n"
                           "IM: 9.041.041-5\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1]; // Alignment
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendData:[@"--------------------------------\r\n"
                           "MM/DD/YYYY HH:MM:SS\r\n"
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
    [commands appendBytes:"\x1b\x69\x00\x01" length:sizeof("\x1b\x69\x00\x01") - 1];
    
    [commands appendData:[@"TOTAL  R$  27,23\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1];
    
    [commands appendData:[@"DINHEIROv                  29,00\r\n"
                           "TROCO R$                    1,77\r\n"
                           "Valor dos Tributos R$2,15(7,90%)\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"ITEM(S) CINORADIS 5\r\n"
                           "OP.:15326  PDV:9  BR,BF:93466\r\n"
                           "OBRIGADO PERA PREFERENCIA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x06\x09\x1b\x69\x00\x01" length:sizeof("\x06\x09\x1b\x69\x00\x01") - 1];
    
    [commands appendData:[@"VOLTE SEMPRE!\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x06\x09\x1b\x69\x00\x00" length:sizeof("\x06\x09\x1b\x69\x00\x00") - 1];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];
    
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
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"DDDDDDDDDAEHFGBFCC\r\n"
                           "MM/DD/YYYY HH:MM:SS\r\n"
                           "FAB:DR0911BR000000275026\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];
    
    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];
    
    [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut

    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

+ (NSData *)portuguese3inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x1d\x74\x20" length:sizeof("\x1b\x1d\x74\x20") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x44\x02\x06\x0a\x10\x14\x1a\x22\x24\x28\x00"
                   length:sizeof("\x1b\x44\x02\x06\x0a\x10\x14\x1a\x22\x24\x28\x00") - 1]; // Set horizontal tab
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x06\x09\x1b\x69\x01\x00" length:sizeof("\x06\x09\x1b\x69\x01\x00") - 1];

    [commands appendData:[@"\nCOMERCIAL DE ALIMENTOS CARREFOUR LTDA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"Avenida Moyses Roysen, S/N  Vila Guilherme\r\n"
                           "Cep: 02049-010 – Sao Paulo – SP\r\n"
                           "CNPJ: 62.545.579/0013-69\r\n"
                           "IE:110.819.138.118  IM: 9.041.041-5\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1]; // Alignment
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendData:[@"------------------------------------------------\r\n"
                           "MM/DD/YYYY HH:MM:SS  CCF:133939 COO:227808\r\n"
                           "------------------------------------------------\r\n"
                           "CUPOM FISCAL\r\n"
                           "------------------------------------------------\r\n"
                           "001  2505  CAFÉ DO PONTO TRAD A  1un F1  8,15)\r\n"
                           "002  2505  CAFÉ DO PONTO TRAD A  1un F1  8,15)\r\n"
                           "003  2505  CAFÉ DO PONTO TRAD A  1un F1  8,15)\r\n"
                           "004  6129  AGU MIN NESTLE 510ML  1un F1  1,39)\r\n"
                           "005  6129  AGU MIN NESTLE 510ML  1un F1  1,39)\r\n"
                           "------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    // Character expansion
    [commands appendBytes:"\x1b\x69\x00\x01" length:sizeof("\x1b\x69\x00\x01") - 1];
    
    [commands appendData:[@"TOTAL  R$ \t\t\t 27,23\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1];
    
    [commands appendData:[@"DINHEIROv \t\t\t\t\t\t       29,00\r\n"
                           "TROCO R$  \t\t\t\t\t\t        1,77\r\n"
                           "Valor dos Tributos R$2,15 (7,90%)\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"ITEM(S) CINORADIS 5\r\n"
                           "OP.:15326  PDV:9  BR,BF:93466\r\n"
                           "OBRIGADO PERA PREFERENCIA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x06\x09\x1b\x69\x00\x01" length:sizeof("\x06\x09\x1b\x69\x00\x01") - 1];
    
    [commands appendData:[@"VOLTE SEMPRE!\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x06\x09\x1b\x69\x00\x00" length:sizeof("\x06\x09\x1b\x69\x00\x00") - 1];
    
    [commands appendData:[@"SAC 0800 724 2822\r\n"
                           "------------------------------------------------\r\n"
                           "MD5:fe028828a532a7dbaf4271155aa4e2db\r\n"
                           "Calypso_CA CA.20.c13 – Unisys Brasil\r\n"
                           "------------------------------------------------\r\n"
                           "DARUMA AUTOMAÇÃO   MACH 2\r\n"
                           "ECF-IF VERSÃO:01,00,00 ECF:093\r\n"
                           "Lj:0204 OPR:ANGELA JORGE\r\n"
                           "DDDDDDDDDAEHFGBFCC\r\n"
                           "MM/DD/YYYY HH:MM:SS\r\n"
                           "FAB:DR0911BR000000275026\r\n" dataUsingEncoding:ENCODING]];

    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];
    
    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];
    
    [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut

    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

+ (NSData *)portuguese4inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];

    [commands appendBytes:"\x1b\x1d\x74\x20" length:sizeof("\x1b\x1d\x74\x20") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x44\x06\x0a\x10\x14\x1a\x22\x24\x28\x30\x3a\x40\x00"
                   length:sizeof("\x1b\x44\x06\x0a\x10\x14\x1a\x22\x24\x28\x30\x3a\x40\x00") - 1]; // Set horizontal tab
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x06\x09\x1b\x69\x01\x00" length:sizeof("\x06\x09\x1b\x69\x01\x00") - 1];

    [commands appendData:[@"\nCOMERCIAL DE ALIMENTOS CARREFOUR LTDA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"Avenida Moyses Roysen, S/N  Vila Guilherme\r\n"
                           "Cep: 02049-010 – Sao Paulo – SP\r\n"
                           "CNPJ: 62.545.579/0013-69\r\n"
                           "IE:110.819.138.118  IM: 9.041.041-5\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "MM/DD/YYYY HH:MM:SS  CCF:133939 COO:227808\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1]; // Alignment
    
    [commands appendData:[@"---------------------------------------------------------------------\r\n"
                           "CUPOM FISCAL\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "001  2505 \t CAFÉ DO PONTO TRAD A \t 1un F1 \t 8,15)\r\n"
                           "002  2505 \t CAFÉ DO PONTO TRAD A \t 1un F1 \t 8,15)\r\n"
                           "003  2505 \t CAFÉ DO PONTO TRAD A \t 1un F1 \t 8,15)\r\n"
                           "004  6129 \t AGU MIN NESTLE 510ML \t 1un F1 \t 1,39)\r\n"
                           "005  6129 \t AGU MIN NESTLE 510ML \t 1un F1 \t 1,39)\r\n"
                           "---------------------------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    // Character expansion
    [commands appendBytes:"\x1b\x69\x00\x01" length:sizeof("\x1b\x69\x00\x01") - 1];
    
    [commands appendData:[@"TOTAL  R$ \t\t\t\t\t   27,23\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1];
    
    [commands appendData:[@"DINHEIROv \t\t\t\t\t\t\t           29,00\r\n"
                           "TROCO R$  \t\t\t\t\t\t\t            1,77\r\n"
                           "Valor dos Tributos R$2,15 (7,90%)\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    [commands appendData:[@"ITEM(S) CINORADIS 5\r\n"
                           "OP.:15326  PDV:9  BR,BF:93466\r\n"
                           "OBRIGADO PERA PREFERENCIA.\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x06\x09\x1b\x69\x00\x01" length:sizeof("\x06\x09\x1b\x69\x00\x01") - 1];
    
    [commands appendData:[@"VOLTE SEMPRE!\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x06\x09\x1b\x69\x00\x00" length:sizeof("\x06\x09\x1b\x69\x00\x00") - 1];
    
    [commands appendData:[@"SAC 0800 724 2822\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "MD5:fe028828a532a7dbaf4271155aa4e2db\r\n"
                           "Calypso_CA CA.20.c13 – Unisys Brasil\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "DARUMA AUTOMAÇÃO   MACH 2\r\n"
                           "ECF-IF VERSÃO:01,00,00 ECF:093\r\n"
                           "Lj:0204 OPR:ANGELA JORGE\r\n"
                           "DDDDDDDDDAEHFGBFCC\r\n"
                           "MM/DD/YYYY HH:MM:SS\r\n"
                           "FAB:DR0911BR000000275026\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];
    
    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];
    
    [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut
    
    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

+ (NSData *)spanish2inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x1d\x74\x20" length:sizeof("\x1b\x1d\x74\x20") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x06\x09\x1b\x69\x01\x01" length:sizeof("\x06\x09\x1b\x69\x01\x01") - 1];


    [commands appendData:[@"BAR RESTAURANT\r\n"
                           "EL POZO\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"C/.ROCAFORT 187\r\n"
                           "08029 BARCELONA\r\n\r\n"
                           "NIF :X-3856907Z\r\n"
                           "TEL :934199465\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1]; // Alignment
    
    [commands appendBytes:"\x1b\x44\x02\x10\x22\x00" length:sizeof("\x1b\x44\x02\x10\x22\x00") - 1]; // Set horizontal tab
    
    [commands appendData:[@"--------------------------------\r\n"
                           "MESA: 100 P: - FECHA: YYYY-MM-DD\r\n"
                           "CAN P/U DESCRIPCION  SUMA\r\n"
                           "--------------------------------\r\n"
                           " 4  3,00  JARRA  CERVESA   12,00\r\n"
                           " 1  1,60  COPA DE CERVESA   1,60\r\n"
                           "--------------------------------\r\n"
                           "               SUB TOTAL : 13,60\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x09\x1b\x69\x01\x00" length:sizeof("\x09\x1b\x69\x01\x00") - 1];
    [commands appendBytes:"\x1b\x1d\x61\x02" length:sizeof("\x1b\x1d\x61\x02") - 1];
    [commands appendData:[@"TOTAL:     13,60 EUROS\r\n" dataUsingEncoding:ENCODING]];
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];
    [commands appendBytes:"\x09\x1b\x69\x00\x00" length:sizeof("\x09\x1b\x69\x00\x00") - 1];
    
    [commands appendData:[@"NO: 000018851     IVA INCLUIDO\r\n"
                           "--------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendData:[@"**** GRACIAS POR SU VISITA! ****\r\n" dataUsingEncoding:ENCODING]];
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];
    
    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];
    
    [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut

    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

+ (NSData *)spanish3inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x1d\x74\x20" length:sizeof("\x1b\x1d\x74\x20") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x44\x02\x06\x0a\x10\x14\x1a\x22\x24\x28\x00" length:sizeof("\x1b\x44\x02\x06\x0a\x10\x14\x1a\x22\x24\x28\x00") - 1]; // Set horizontal tab
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1b\x69\x01\x01" length:sizeof("\x1b\x69\x01\x01") - 1];

    [commands appendData:[@"BAR RESTAURANT EL POZO\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"C/.ROCAFORT 187 08029 BARCELONA\r\n"
                           "NIF :X-3856907Z  TEL :934199465\r\n"
                           "------------------------------------------------\r\n"
                           "MESA: 100 P: - FECHA: YYYY-MM-DD\r\n"
                           "CAN P/U DESCRIPCION  SUMA\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1]; // Alignment
    
    [commands appendData:[@"------------------------------------------------\r\n"
                           " 4\t 3,00\t JARRA  CERVESA \t\t 12,00\r\n"
                           " 1\t 1,60\t COPA DE CERVESA\t\t  1,60\r\n"
                           "------------------------------------------------\r\n"
                           "\t\t\t\t\t SUB TOTAL :\t\t 13,60\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x09\x1b\x69\x01\x00" length:sizeof("\x09\x1b\x69\x01\x00") - 1];
    [commands appendBytes:"\x1b\x1d\x61\x02" length:sizeof("\x1b\x1d\x61\x02") - 1];
    [commands appendData:[@"TOTAL:     13,60 EUROS\r\n" dataUsingEncoding:ENCODING]];
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1];
    
    [commands appendData:[@"NO: 000018851  IVA INCLUIDO\r\n"
                           "------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendData:[@"**** GRACIAS POR SU VISITA! ****\r\n" dataUsingEncoding:ENCODING]];
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];
    
    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];
    
    [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut

    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

+ (NSData *)spanish4inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1252StringEncoding;

    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x1d\x74\x20" length:sizeof("\x1b\x1d\x74\x20") - 1]; // Code Page #1252 (Windows Latin-1)
    
    [commands appendBytes:"\x1b\x44\x06\x0a\x10\x14\x1a\x22\x24\x28\x30\x3a\x40\x00"
                   length:sizeof("\x1b\x44\x06\x0a\x10\x14\x1a\x22\x24\x28\x30\x3a\x40\x00") - 1]; // Set horizontal tab
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1]; // Alignment (center)
    
    // [commands appendData:[@"[If loaded.. Logo1 goes here]\r\n" dataUsingEncoding:NSWindowsCP1252StringEncoding]];
    
    // [commands appendBytes:"\x1b\x1c\x70\x01\x00\r\n" length:sizeof("\x1b\x1c\x70\x01\x00\r\n") - 1]; // Stored Logo Printing
    
    // Character expansion
    [commands appendBytes:"\x1b\x69\x01\x01" length:sizeof("\x1b\x69\x01\x01") - 1];

    [commands appendData:[@"BAR RESTAURANT EL POZO\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1]; // Cancel Character Expansion
    
    [commands appendData:[@"C/.ROCAFORT 187 08029 BARCELONA\r\n"
                           "NIF :X-3856907Z  TEL :934199465\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "MESA: 100 P: - FECHA: YYYY-MM-DD\r\n"
                           "CAN P/U DESCRIPCION  SUMA\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1]; // Alignment
    
    [commands appendData:[@"---------------------------------------------------------------------\r\n"
                           " 4\t 3,00\t\t JARRA  CERVESA \t\t\t 12,00\r\n"
                           " 1\t 1,60\t\t COPA DE CERVESA\t\t\t  1,60\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "\t\t\t\t\t\t\t\t SUB TOTAL :\t 13,60\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x09\x1b\x69\x01\x00" length:sizeof("\x09\x1b\x69\x01\x00") - 1];
    [commands appendBytes:"\x1b\x1d\x61\x02" length:sizeof("\x1b\x1d\x61\x02") - 1];
    [commands appendData:[@"TOTAL:     13,60 EUROS\r\n" dataUsingEncoding:ENCODING]];
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];
    [commands appendBytes:"\x1b\x69\x00\x00" length:sizeof("\x1b\x69\x00\x00") - 1];
    
    [commands appendData:[@"NO: 000018851  IVA INCLUIDO\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendData:[@"---------------------------------------------------------------------\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendData:[@"**** GRACIAS POR SU VISITA! ****\r\n" dataUsingEncoding:ENCODING]];
    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];
    
    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];
    
    [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut

    NSData *result = [NSData dataWithData:commands];
    
    return result;
}

+ (NSData *)russian2inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1251StringEncoding;
    
    NSMutableData *commands = [NSMutableData data];

    [commands appendBytes:"\x1b\x1d\x74\x22" length:4]; // Character Set (CP1251)
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:4]; // Alignment (Center)
    [commands appendBytes:"\x1b\x69\x01\x01" length:4];    // Set Double HW
    [commands appendData:[@"Р Е Л А К С\n" dataUsingEncoding:ENCODING]];
    [commands appendBytes:"\x1b\x69\x00\x00" length:4];    // Cancel Double HW
    
    [commands appendData:[@"ООО “РЕЛАКС”\n"
                          "СПб., Малая Балканская, д. 38, лит. А\n"
                          "тел. 307-07-12\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:4]; // Alignment (Left)
    [commands appendData:[@"РЕГ №322736     \tИНН:123321\n"
                           "01 Белякова И.А.\tКАССА: 0020 ОТД.01\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:4]; // Alignment (Center)
    [commands appendData:[@"ЧЕК НА ПРОДАЖУ  No 84373\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:4]; // Alignment (Left)
    [commands appendData:[@"--------------------------------\n"
                           " 1. Яблоки Айдаред, кг    144.50\n"
                           " 2. Соус соевый Sen So     36.40\n"
                           " 3. Соус томатный Клас     19.90\n"
                           " 4. Ребра свиные в.к м     78.20\n"
                           " 5. Масло подсол раф д    114.00\n"
                           " 6. Блокнот 10х14см сп    164.00\n"
                           " 7. Морс Северная Ягод     99.90\n"
                           " 8. Активия Биойогурт      43.40\n"
                           " 9. Бублики Украинские     26.90\n"
                           "10. Активия Биойогурт      43.40\n"
                           "11. Сахар-песок 1кг        58.40\n"
                           "12. Хлопья овсяные Ясн     38.40\n"
                           "13. Кинза 50г              39.90\n"
                           "14. Пемза “Сердечко” .Т    37.90\n"
                           "15. Приправа Santa Mar     47.90\n"
                           "16. Томаты слива Выбор    162.00\n"
                           "17. Бонд Стрит Ред Сел     56.90\n"
                           "--------------------------------\n"
                           "--------------------------------\n"
                           "ДИСКОНТНАЯ КАРТА\n"
                           "                No:2440012489765\n"
                           "--------------------------------\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x02" length:4]; // Alignment (Right)

    [commands appendData:[@"ИТОГО К ОПЛАТЕ = 1212.00\n" dataUsingEncoding:ENCODING]];
    [commands appendData:[@"НАЛИЧНЫЕ = 1212.00\n"
                          "ВАША СКИДКА : 0.41\n\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x01" length:4]; // Alignment (Center)
    [commands appendData:[@"ЦЕНЫ УКАЗАНЫ С УЧЕТОМ СКИДКИ\n\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x1d\x61\x00" length:4]; // Alignment (Left)
    [commands appendData:[@"08-02-2015 09:49  0254.0130604\n"
                           "00083213 #060127\n" dataUsingEncoding:ENCODING]];
                          
    [commands appendBytes:"\x1b\x1d\x61\x01" length:4]; // Alignment (Center)
    [commands appendData:[@"СПАСИБО ЗА ПОКУПКУ !\n"
                           "МЫ  ОТКРЫТЫ ЕЖЕДНЕВНО С 9 ДО 23\n"
                           "СОХРАНЯЙТЕ, ПОЖАЛУЙСТА , ЧЕК\n" dataUsingEncoding:ENCODING]];
    
    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut
    
    return commands;
}

+ (NSData *)russian3inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x1d\x74\x22" length:sizeof("\x1b\x1d\x74\x22") - 1]; // Code Page #1251 (Windows Latin-1)

    [commands appendBytes:"\x1b\x44\x02\x06\x0a\x10\x14\x1a\x22\x24\x28\x00"
                   length:sizeof("\x1b\x44\x02\x06\x0a\x10\x14\x1a\x22\x24\x28\x00") - 1]; // Set horizontal tab

    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];

    [commands appendData:[@"Р  Е  Л  А  К  С\n"
                           "ООО “РЕЛАКС”\n"
                           "СПб., Малая Балканская, д. 38, лит. А\n"
                           "тел. 307-07-12\n"
                           "РЕГ №322736 ИНН : 123321\n"
                           "01  Белякова И.А.  КАССА: 0020 ОТД.01\n"
                           "ЧЕК НА ПРОДАЖУ  No 84373\n" dataUsingEncoding:NSWindowsCP1251StringEncoding]];

    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];

    [commands appendData:[@"------------------------------------------------\r\n"
                           "1. \t Яблоки Айдаред, кг \t        144.50\n"
                           "2. \t Соус соевый Sen So \t         36.40\n"
                           "3. \t Соус томатный Клас \t         19.90\n"
                           "4. \t Ребра свиные в.к м \t         78.20\n"
                           "5. \t Масло подсол раф д \t        114.00\n"
                           "6. \t Блокнот 10х14см сп \t        164.00\n"
                           "7. \t Морс Северная Ягод \t         99.90\n"
                           "8. \t Активия Биойогурт  \t         43.40\n"
                           "9. \t Бублики Украинские \t         26.90\n"
                           "10.\t Активия Биойогурт  \t         43.40\n"
                           "11.\t Сахар-песок 1кг    \t         58.40\n"
                           "12.\t Хлопья овсяные Ясн \t         38.40\n"
                           "13.\t Кинза 50г          \t         39.90\n"
                           "14.\t Пемза “Сердечко” .Т\t         37.90\n"
                           "15.\t Приправа Santa Mar \t         47.90\n"
                           "16.\t Томаты слива Выбор \t        162.00\n"
                           "17.\t Бонд Стрит Ред Сел \t         56.90\n"
                           "------------------------------------------------\r\n"
                           "------------------------------------------------\r\n"
                           "ДИСКОНТНАЯ КАРТА  No: 2440012489765\n"
                           "------------------------------------------------\r\n"
                           "ИТОГО  К  ОПЛАТЕ \t = 1212.00\n" dataUsingEncoding:NSWindowsCP1251StringEncoding]];
    
    [commands appendData:[@"НАЛИЧНЫЕ         \t = 1212.00\n"
                           "ВАША СКИДКА : 0.41\n" dataUsingEncoding:NSWindowsCP1251StringEncoding]];

    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];

    [commands appendData:[@"ЦЕНЫ УКАЗАНЫ С УЧЕТОМ СКИДКИ\n"
                           "08-02-2015 09:49  0254.0130604\n"
                           "00083213 #060127\n"
                           "СПАСИБО ЗА ПОКУПКУ !\n"
                           "МЫ  ОТКРЫТЫ ЕЖЕДНЕВНО С 9 ДО 23\n"
                           "СОХРАНЯЙТЕ, ПОЖАЛУЙСТА , ЧЕК\n" dataUsingEncoding:NSWindowsCP1251StringEncoding]];

    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];

    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];

    [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:NSWindowsCP1251StringEncoding]];

    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut

    return commands;
}

+ (NSData *)russian4inchSampleReceipt
{
    const NSStringEncoding ENCODING = NSWindowsCP1251StringEncoding;
    
    NSMutableData *commands = [NSMutableData data];

    [commands appendBytes:"\x1b\x1d\x74\x22" length:sizeof("\x1b\x1d\x74\x22") - 1]; // Code Page #1251 (Windows Latin-1)

    [commands appendBytes:"\x1b\x44\x06\x0a\x10\x14\x1a\x22\x24\x28\x30\x3a\x40\x00"
                   length:sizeof("\x1b\x44\x06\x0a\x10\x14\x1a\x22\x24\x28\x30\x3a\x40\x00") - 1]; // Set horizontal tab

    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];

    [commands appendData:[@"Р  Е  Л  А  К  С\n"
                           "ООО “РЕЛАКС”\n"
                           "СПб., Малая Балканская, д. 38, лит. А\n"
                           "тел. 307-07-12\n"
                           "РЕГ №322736 ИНН : 123321\n"
                           "01  Белякова И.А.  КАССА: 0020 ОТД.01\n"
                           "ЧЕК НА ПРОДАЖУ  No 84373\n" dataUsingEncoding:ENCODING]];

    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];

    [commands appendData:[@"---------------------------------------------------------------------\r\n"
                           "1. \t Яблоки Айдаред, кг \t\t\t\t\t     144.50\n"
                           "2. \t Соус соевый Sen So \t\t\t\t\t      36.40\n"
                           "3. \t Соус томатный Клас \t\t\t\t\t      19.90\n"
                           "4. \t Ребра свиные в.к м \t\t\t\t\t      78.20\n"
                           "5. \t Масло подсол раф д \t\t\t\t\t     114.00\n"
                           "6. \t Блокнот 10х14см сп \t\t\t\t\t     164.00\n"
                           "7. \t Морс Северная Ягод \t\t\t\t\t      99.90\n"
                           "8. \t Активия Биойогурт  \t\t\t\t\t      43.40\n"
                           "9. \t Бублики Украинские \t\t\t\t\t      26.90\n"
                           "10.\t Активия Биойогурт  \t\t\t\t\t      43.40\n"
                           "11.\t Сахар-песок 1кг    \t\t\t\t\t      58.40\n"
                           "12.\t Хлопья овсяные Ясн \t\t\t\t\t      38.40\n"
                           "13.\t Кинза 50г          \t\t\t\t\t      39.90\n"
                           "14.\t Пемза “Сердечко” .Т\t\t\t\t\t      37.90\n"
                           "15.\t Приправа Santa Mar \t\t\t\t\t      47.90\n"
                           "16.\t Томаты слива Выбор \t\t\t\t\t     162.00\n"
                           "17.\t Бонд Стрит Ред Сел \t\t\t\t\t      56.90\n"
                           "---------------------------------------------------------------------\r\n"
                           "---------------------------------------------------------------------\r\n"
                           "ДИСКОНТНАЯ КАРТА  No: 2440012489765\n"
                           "---------------------------------------------------------------------\r\n"
                           "ИТОГО  К  ОПЛАТЕ \t\t = 1212.00\n"
                           "НАЛИЧНЫЕ         \t\t = 1212.00\n"
                           "ВАША СКИДКА : 0.41\n" dataUsingEncoding:ENCODING]];

    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];

    [commands appendData:[@"ЦЕНЫ УКАЗАНЫ С УЧЕТОМ СКИДКИ\n"
                           "08-02-2015 09:49  0254.0130604\n"
                           "00083213 #060127\n"
                           "СПАСИБО ЗА ПОКУПКУ !\n"
                           "МЫ  ОТКРЫТЫ ЕЖЕДНЕВНО С 9 ДО 23\n"
                           "СОХРАНЯЙТЕ, ПОЖАЛУЙСТА , ЧЕК\n" dataUsingEncoding:ENCODING]];

    [commands appendBytes:"\x1b\x1d\x61\x00" length:sizeof("\x1b\x1d\x61\x00") - 1];

    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01" length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x06\x02\x02" length:sizeof("\x1b\x62\x06\x02\x02") - 1];

    [commands appendData:[@" 12ab34cd56\x1e\r\n" dataUsingEncoding:ENCODING]];

    [commands appendBytes:"\x1b\x64\x02" length:sizeof("\x1b\x64\x02") - 1]; // Cut

    return commands;
}

/**
 *  Japanese Sample Receipt (2inch)
 */
+ (NSData *)japanese2inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
                   length:sizeof("\x1b\x40") - 1];    // 初期化
    
    [commands appendBytes:"\x1b\x24\x31"
                   length:sizeof("\x1b\x24\x31") - 1];    // 漢字モード設定
    
    [commands appendBytes:"\x1b\x1d\x61\x31"
                   length:sizeof("\x1b\x1d\x61\x31") - 1];    // 中央揃え設定
    
    [commands appendBytes:"\x1b\x69\x02\x00"
                   length:sizeof("\x1b\x69\x02\x00") - 1];    // 文字縦拡大設定
    
    [commands appendBytes:"\x1b\x45"
                   length:sizeof("\x1b\x45") - 1];    // 強調印字設定
    
    [commands appendData:[@"スター電機\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x69\x01\x00"
                   length:sizeof("\x1b\x69\x01\x00") - 1];    // 文字縦拡大設定
    
    [commands appendData:[@"修理報告書　兼領収書\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x69\x00\x00"
                   length:sizeof("\x1b\x69\x00\x00") - 1];    // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x46"
                   length:sizeof("\x1b\x46") - 1];    // 強調印字解除
    
    [commands appendData:[@"--------------------------------\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // 左揃え設定
    
    [commands appendData:[@"発行日時：YYYY年MM月DD日HH時MM分" "\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"TEL：054-347-XXXX\n\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"         ｲｹﾆｼ  ｼｽﾞｺ   ｻﾏ\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"お名前：池西　静子　様\n"
                           "御住所：静岡市清水区七ツ新屋\n"
                           "　　　　５３６番地\n"
                           "伝票番号：No.12345-67890\n\n"
                           "　この度は修理をご用命頂き有難うございます。\n"
                           " 今後も故障など発生した場合はお気軽にご連絡ください。\n\n"
                           dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x52\x08" length:sizeof("\x1b\x52\x08") - 1];  // 国際文字:日本
    
    [commands appendData:[@"品名／型名　数量　金額　備考\n"
                           "--------------------------------\n"
                           "制御基板　　   1 10,000  配達\n"
                           "操作スイッチ   1  3,800  配達\n"
                           "パネル　　　   1  2,000  配達\n"
                           "技術料　　　   1 15,000\n"
                           "出張費用　　   1  5,000\n"
                           "--------------------------------\n"
                           dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"\n"
                           "             小計      \\ 35,800\n"
                           "             内税      \\  1,790\n"
                           "             合計      \\ 37,590\n\n"
                           "　お問合わせ番号　12345-67890\n\n\n\n"
                           dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x64\x33"
                   length:sizeof("\x1b\x64\x33") - 1];    // カット

    return commands;
}

/*!
 *  Japanese Sample Receipt (3inch)
 */
+ (NSData *)japanese3inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];

    [commands appendBytes:"\x1b\x40"
            length:sizeof("\x1b\x40") - 1];    // 初期化

    [commands appendBytes:"\x1b\x24\x31"
            length:sizeof("\x1b\x24\x31") - 1];    // 漢字モード設定

    [commands appendBytes:"\x1b\x1d\x61\x31"
            length:sizeof("\x1b\x1d\x61\x31") - 1];    // 中央揃え設定

    [commands appendBytes:"\x1b\x69\x02\x00"
            length:sizeof("\x1b\x69\x02\x00") - 1];    // 文字縦拡大設定

    [commands appendBytes:"\x1b\x45"
            length:sizeof("\x1b\x45") - 1];    // 強調印字設定

    [commands appendData:[@"スター電機\n" dataUsingEncoding:NSShiftJISStringEncoding]];

    [commands appendBytes:"\x1b\x69\x01\x00"
            length:sizeof("\x1b\x69\x01\x00") - 1];    // 文字縦拡大設定

    [commands appendData:[@"修理報告書　兼領収書\n" dataUsingEncoding:NSShiftJISStringEncoding]];

    [commands appendBytes:"\x1b\x69\x00\x00"
            length:sizeof("\x1b\x69\x00\x00") - 1];    // 文字縦拡大解除

    [commands appendBytes:"\x1b\x46"
            length:sizeof("\x1b\x46") - 1];    // 強調印字解除

    [commands appendData:[@"------------------------------------------------\n" dataUsingEncoding:NSShiftJISStringEncoding]];

    [commands appendBytes:"\x1b\x1d\x61\x30"
            length:sizeof("\x1b\x1d\x61\x30") - 1];    // 左揃え設定

    [commands appendData:[@"発行日時：YYYY年MM月DD日HH時MM分" "\n" dataUsingEncoding:NSShiftJISStringEncoding]];

    [commands appendData:[@"TEL：054-347-XXXX\n\n" dataUsingEncoding:NSShiftJISStringEncoding]];

    [commands appendData:[@"           ｲｹﾆｼ  ｼｽﾞｺ   ｻﾏ\n" dataUsingEncoding:NSShiftJISStringEncoding]];

    [commands appendData:[@"　お名前：池西　静子　様\n"
                           "　御住所：静岡市清水区七ツ新屋\n"
                           "　　　　　５３６番地\n"
                           "　伝票番号：No.12345-67890\n\n"
                           "　この度は修理をご用命頂き有難うございます。\n"
                           " 今後も故障など発生した場合はお気軽にご連絡ください。\n\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x52\x08" length:sizeof("\x1b\x52\x08") - 1];  // 国際文字:日本

    [commands appendData:[@"品名／型名　          数量      金額　   備考\n"
                           "------------------------------------------------\n"
                           "制御基板　          　  1      10,000     配達\n"
                           "操作スイッチ            1       3,800     配達\n"
                           "パネル　　          　  1       2,000     配達\n"
                           "技術料　          　　  1      15,000\n"
                           "出張費用　　            1       5,000\n"
                           "------------------------------------------------\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"\n"
                           "                            小計       \\ 35,800\n"
                           "                            内税       \\  1,790\n"
                           "                            合計       \\ 37,590\n\n"
                           "　お問合わせ番号　　12345-67890\n\n\n\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];

    [commands appendBytes:"\x1b\x64\x33"
            length:sizeof("\x1b\x64\x33") - 1];    // カット

    return commands;
}

/**
 *  Japanese sample receipt (4inch)
 */
+ (NSData *)japanese4inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
            length:sizeof("\x1b\x40") - 1];    // 初期化
    
    [commands appendBytes:"\x1b\x24\x31"
            length:sizeof("\x1b\x24\x31") - 1];    // 漢字モード設定
    
    [commands appendBytes:"\x1b\x1d\x61\x31"
            length:sizeof("\x1b\x1d\x61\x31") - 1];    // 中央揃え設定
    
    [commands appendBytes:"\x1b\x69\x02\x00"
            length:sizeof("\x1b\x69\x02\x00") - 1];    // 文字縦拡大設定
    
    [commands appendBytes:"\x1b\x45"
            length:sizeof("\x1b\x45") - 1];    // 強調印字設定
    
    [commands appendData:[@"スター電機\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x69\x01\x00"
            length:sizeof("\x1b\x69\x01\x00") - 1];    // 文字縦拡大設定
    
    [commands appendData:[@"修理報告書　兼領収書\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x69\x00\x00"
            length:sizeof("\x1b\x69\x00\x00") - 1];    // 文字縦拡大解除
    
    [commands appendBytes:"\x1b\x46"
            length:sizeof("\x1b\x46") - 1];    // 強調印字解除

    [commands appendData:[@"---------------------------------------------------------------------\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
            length:sizeof("\x1b\x1d\x61\x30") - 1];    // 左揃え設定
    
    [commands appendData:[@"発行日時：YYYY年MM月DD日HH時MM分" "\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"TEL：054-347-XXXX\n\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"           ｲｹﾆｼ  ｼｽﾞｺ   ｻﾏ\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"　お名前：池西　静子　様\n"
                           "　御住所：静岡市清水区七ツ新屋\n"
                           "　　　　　５３６番地\n"
                           "　伝票番号：No.12345-67890\n\n"
                           "この度は修理をご用命頂き有難うございます。\n"
                           " 今後も故障など発生した場合はお気軽にご連絡ください。\n\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x52\x08" length:sizeof("\x1b\x52\x08") - 1];  // 国際文字:日本
    
    [commands appendData:[@"品名／型名　                 数量             金額　          備考\n"
                           "---------------------------------------------------------------------\n"
                           "制御基板　　                   1             10,000            配達\n"
                           "操作スイッチ                   1              3,800            配達\n"
                           "パネル　　　                   1              2,000            配達\n"
                           "技術料　　　                   1             15,000\n"
                           "出張費用　　                   1              5,000\n"
                           "---------------------------------------------------------------------\n"
                          dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendData:[@"\n"
                           "                                                 小計       \\ 35,800\n"
                           "                                                 内税       \\  1,790\n"
                           "                                                 合計       \\ 37,590\n\n"
                           "　お問合わせ番号　　12345-67890\n\n\n\n" dataUsingEncoding:NSShiftJISStringEncoding]];
    
    [commands appendBytes:"\x1b\x64\x33"
            length:sizeof("\x1b\x64\x33") - 1];    // カット

    return commands;
}

/**
 *  Simplified Chinese Sample Receipt (2inch)
 */
+ (NSData *)simplifiedChinese2inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
                   length:sizeof("\x1b\x40") - 1];            // Initialize
    
    [commands appendBytes:"\x1b\x44\x10\x00"
                   length:sizeof("\x1b\x44\x10\x00") - 1];    // Set HT
    
    [commands appendBytes:"\x1b\x1d\x61\x31"
                   length:sizeof("\x1b\x1d\x61\x31") - 1];    // Alignment (Center)
    
    [commands appendBytes:"\x1b\x69\x02\x00"
                   length:sizeof("\x1b\x69\x02\x00") - 1];    // Set Double HW
    
    [commands appendBytes:"\x1b\x45"
                   length:sizeof("\x1b\x45") - 1];            // Set Bold
    
    [commands appendData:[@"STAR便利店\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x69\x01\x00"
                   length:sizeof("\x1b\x69\x01\x00") - 1];    // Set Double HW
    
    [commands appendData:[@"欢迎光临\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x69\x00\x00"
                   length:sizeof("\x1b\x69\x00\x00") - 1];    // Cancel Double HW
    [commands appendBytes:"\x1b\x46"
                   length:sizeof("\x1b\x46") - 1];            // Cancel Bold
    
    [commands appendData:[@"Unit 1906-08, 19/F, Enterprise Square 2,\n"
                          "　3 Sheung Yuet Road, Kowloon Bay, KLN\n"
                          "\n"
                          "Tel : (852) 2795 2335\n"
                          "\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // Alignment (Left)
    
    [commands appendData:[@"货品名称        数量     价格\n"
                           "-----------------------------\n"
                           "\n"
                           "罐装可乐\n"
                           "* Coke              1    7.00\n"
                           "纸包柠檬茶\n"
                           "* Lemon Tea         2   10.00\n"
                           "热狗\n"
                           "* Hot Dog   \x09    1   10.00\n"
                           "薯片(50克装)\n"
                           "* Potato Chips(50g) 1   11.00\n"
                           "-----------------------------\n"
                           "\n"
                           "           总数 :       38.00\n"
                           "           现金 :       38.00\n"
                           "           找赎 :        0.00\n"
                           "\n"
                           "卡号码 Card No.    : 88888888\n"
                           "卡余额 Remaining Val. : 88.00\n"
                           "机号   Device No.    : 1234F1\n"
                           "\n"
                           "\n"
                           "DD/MM/YYYY  HH:MM:SS  \n"
                           "交易编号 : 88888\n"
                           "\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x1d\x61\x31"
                   length:sizeof("\x1b\x1d\x61\x31") - 1];    // Alignment (Center)
    
    [commands appendData:[@"收银机 : 001  收银员 : 180\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // Alignment (Left)
    
    [commands appendBytes:"\x1b\x64\x33"
                   length:sizeof("\x1b\x64\x33") - 1];        // Cut

    return commands;
}

/**
 *  Simplified Chinese Sample Receipt (3inch)
 */
+ (NSData *)simplifiedChinese3inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
                   length:sizeof("\x1b\x40") - 1];            // Initialize
    
    [commands appendBytes:"\x1b\x44\x10\x00"
                   length:sizeof("\x1b\x44\x10\x00") - 1];    // Set HT
    
    [commands appendBytes:"\x1b\x1d\x61\x31"
                   length:sizeof("\x1b\x1d\x61\x31") - 1];    // Alignment (Center)
    
    [commands appendBytes:"\x1b\x69\x02\x00"
                   length:sizeof("\x1b\x69\x02\x00") - 1];    // Set Double HW
    
    [commands appendBytes:"\x1b\x45"
                   length:sizeof("\x1b\x45") - 1];            // Set Bold
    
    [commands appendData:[@"STAR便利店\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x69\x01\x00"
                   length:sizeof("\x1b\x69\x01\x00") - 1];    // Set Double HW
    
    [commands appendData:[@"欢迎光临\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];

    [commands appendBytes:"\x1b\x69\x00\x00"
                   length:sizeof("\x1b\x69\x00\x00") - 1];    // Cancel Double HW

    [commands appendBytes:"\x1b\x46"
                   length:sizeof("\x1b\x46") - 1];            // Cancel Bold
    
    [commands appendData:[@"Unit 1906-08, 19/F, Enterprise Square 2,\n"
                           "　3 Sheung Yuet Road, Kowloon Bay, KLN\n"
                           "\n"
                           "Tel : (852) 2795 2335\n"
                           "\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // Alignment (Left)
 
    [commands appendData:[@"货品名称   　          数量  　   价格\n"
                           "--------------------------------------------\n"
                           "\n"
                           "罐装可乐\n"
                           "* Coke  \x09         1        7.00\n"
                           "纸包柠檬茶\n"
                           "* Lemon Tea  \x09         2       10.00\n"
                           "热狗\n"
                           "* Hot Dog   \x09         1       10.00\n"
                           "薯片(50克装)\n"
                           "* Potato Chips(50g)\x09      1       11.00\n"
                           "--------------------------------------------\n"
                           "\n"
                           "\x09      总数 :\x09     38.00\n"
                           "\x09      现金 :\x09     38.00\n"
                           "\x09      找赎 :\x09      0.00\n"
                           "\n"
                           "卡号码 Card No.       : 88888888\n"
                           "卡余额 Remaining Val. : 88.00\n"
                           "机号   Device No.     : 1234F1\n"
                           "\n"
                           "\n"
                           "DD/MM/YYYY  HH:MM:SS  交易编号 : 88888\n"
                           "\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
 
    [commands appendBytes:"\x1b\x1d\x61\x31"
                   length:sizeof("\x1b\x1d\x61\x31") - 1];    // Alignment (Center)

    [commands appendData:[@"收银机 : 001  收银员 : 180\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];

    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // Alignment (Left)
    
    [commands appendBytes:"\x1b\x64\x33"
                   length:sizeof("\x1b\x64\x33") - 1];        // Cut

    return commands;
}

/**
 *  Simplified Chinese Sample Receipt (4inch)
 */
+ (NSData *)simplifiedChinese4inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
                   length:sizeof("\x1b\x40") - 1];            // Initialize
    
    [commands appendBytes:"\x1b\x44\x10\x00"
                   length:sizeof("\x1b\x44\x10\x00") - 1];    // Set HT
    
    [commands appendBytes:"\x1b\x1d\x61\x31"
                   length:sizeof("\x1b\x1d\x61\x31") - 1];    // Alignment (Center)
    
    [commands appendBytes:"\x1b\x69\x02\x00"
                   length:sizeof("\x1b\x69\x02\x00") - 1];    // Set Double HW
    
    [commands appendBytes:"\x1b\x45"
                   length:sizeof("\x1b\x45") - 1];            // Set Bold
    
    [commands appendData:[@"STAR便利店\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x69\x01\x00"
                   length:sizeof("\x1b\x69\x01\x00") - 1];    // Set Double HW
    
    [commands appendData:[@"欢迎光临\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x69\x00\x00"
                   length:sizeof("\x1b\x69\x00\x00") - 1];    // Cancel Double HW
    
    [commands appendBytes:"\x1b\x46"
                   length:sizeof("\x1b\x46") - 1];            // Cancel Bold
    
    [commands appendData:[@"Unit 1906-08, 19/F, Enterprise Square 2,\n"
                           "　3 Sheung Yuet Road, Kowloon Bay, KLN\n"
                           "\n"
                           "Tel : (852) 2795 2335\n"
                           "\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // Alignment (Left)
    
    [commands appendData:[@"货品名称   　                      数量        　         价格\n"
                           "----------------------------------------------------------------\n"
                           "\n"
                           "罐装可乐\n"
                           "* Coke  \x09                     1                    7.00\n"
                           "纸包柠檬茶\n"
                           "* Lemon Tea  \x09                     2                   10.00\n"
                           "热狗\n"
                           "* Hot Dog   \x09                     1                   10.00\n"
                           "薯片(50克装)\n"
                           "* Potato Chips(50g)\x09                  1                   11.00\n"
                           "----------------------------------------------------------------\n"
                           "\n"
                           "\x09                  总数 :\x09                 38.00\n"
                           "\x09                  现金 :\x09                 38.00\n"
                           "\x09                  找赎 :\x09                  0.00\n"
                           "\n"
                           "卡号码 Card No.                   : 88888888\n"
                           "卡余额 Remaining Val.             : 88.00\n"
                           "机号   Device No.                 : 1234F1\n"
                           "\n"
                           "\n"
                           "DD/MM/YYYY  HH:MM:SS\x09        交易编号 : 88888\n"
                           "\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x1d\x61\x31"
                   length:sizeof("\x1b\x1d\x61\x31") - 1];    // Alignment (Center)
    
    [commands appendData:[@"收银机 : 001  收银员 : 180\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)]];
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // Alignment (Left)
    
    [commands appendBytes:"\x1b\x64\x33"
                   length:sizeof("\x1b\x64\x33") - 1];        // Cut

    return commands;
}

/**
 *  Traditional Chinese Sample Receipt (3inch)
 */
+ (NSData *)traditionalChinese3inchSampleReceipt
{
    NSMutableData *commands = [NSMutableData data];
    
    [commands appendBytes:"\x1b\x40"
                   length:sizeof("\x1b\x40") - 1];            // Initialize
    
    [commands appendBytes:"\x1b\x44\x10\x00"
                   length:sizeof("\x1b\x44\x10\x00") - 1];    // Set HT
    
    [commands appendBytes:"\x1b\x1d\x61\x31"
                   length:sizeof("\x1b\x1d\x61\x31") - 1];    // Alignment (Center)
    
    [commands appendBytes:"\x1b\x69\x02\x00"
                   length:sizeof("\x1b\x69\x02\x00") - 1];    // Set Double HW
    
    [commands appendBytes:"\x1b\x45"
                   length:sizeof("\x1b\x45") - 1];            // Set Bold
    
    [commands appendData:[@"Star Micronics\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];

    [commands appendBytes:"\x1b\x69\x00\x00"
                   length:sizeof("\x1b\x69\x00\x00") - 1];    // Cancel Double HW
    
    [commands appendBytes:"\x1b\x46"
                   length:sizeof("\x1b\x46") - 1];            // Cancel Bold

    [commands appendData:[@"--------------------------------------------\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];

    [commands appendBytes:"\x1b\x69\x01\x01"
                   length:sizeof("\x1b\x69\x01\x01") - 1];    // Set Double HW
    
    [commands appendData:[@"電子發票證明聯\n"
                           "103年01-02月\n"
                           "EV-99999999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x69\x00\x00"
                   length:sizeof("\x1b\x69\x00\x00") - 1];    // Cancel Double HW
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // Alignment (Left)

    [commands appendData:[@"2014/01/15 13:00\n"
                           "隨機碼 : 9999    總計 : 999\n"
                           "賣方 : 99999999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];

    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01"
                   length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x34\x31\x32\x50"
                   length:sizeof("\x1b\x62\x34\x31\x32\x50") - 1];
    
    [commands appendBytes:"999999999\x1e\r\n"
                   length:sizeof("999999999\x1e\r\n") - 1];
    
    
    [commands appendBytes:"\x1b\x1d\x61\x31"
                   length:sizeof("\x1b\x1d\x61\x31") - 1];    // Alignment (Center)
    // QR Code
    [commands appendBytes:"\x1b\x1d\x79\x53\x30\x02"
                   length:sizeof("\x1b\x1d\x79\x53\x30\x02") - 1];            // Model
    [commands appendBytes:"\x1b\x1d\x79\x53\x31\x02"
                   length:sizeof("\x1b\x1d\x79\x53\x31\x02") - 1];            // Error Correction Level
    [commands appendBytes:"\x1b\x1d\x79\x53\x32\x05"
                   length:sizeof("\x1b\x1d\x79\x53\x32\x05") - 1];            // Cell size
    [commands appendBytes:"\x1b\x1d\x79\x44\x31\x00\x23\x00"
                   length:sizeof("\x1b\x1d\x79\x44\x31\x00\x23\x00") - 1];    // Data

    [commands appendBytes:"http://www.star-m.jp/eng/index.html"
                   length:sizeof("http://www.star-m.jp/eng/index.html") - 1];
   
    [commands appendBytes:"\x1b\x1d\x79\x50\x0a"
                   length:sizeof("\x1b\x1d\x79\x50\x0a") - 1];                // Print QR Code
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // Alignment (Left)
    
    [commands appendData:[@"商品退換請持本聯及銷貨明細表。\n"
                           "9999999-9999999 999999-999999 9999\n\n\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];

    [commands appendBytes:"\x1b\x1d\x61\x31"
                   length:sizeof("\x1b\x1d\x61\x31") - 1];    // Alignment (Center)
    
    [commands appendData:[@"銷貨明細表 　(銷售)\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];

    [commands appendBytes:"\x1b\x1d\x61\x32"
                   length:sizeof("\x1b\x1d\x61\x32") - 1];    // Alignment (Right)
    
    [commands appendData:[@"2014-01-15 13:00:02\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // Alignment (Left)

    [commands appendData:[@"\n"
                           "烏龍袋茶2g20入  \x09           55 x2 110TX\n"
                           "茉莉烏龍茶2g20入  \x09         55 x2 110TX\n"
                           "天仁觀音茶2g*20   \x09         55 x2 110TX\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x45"
                   length:sizeof("\x1b\x45") - 1];            // Set Bold
    
    [commands appendData:[@"      小　 計 :\x09             330\n"
                           "      總   計 :\x09             330\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];

    [commands appendBytes:"\x1b\x46"
                   length:sizeof("\x1b\x46") - 1];            // Cancel Bold
    
    [commands appendData:[@"--------------------------------------------\n"
                           "現 金\x09             400\n"
                           "      找　 零 :\x09              70\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];

    [commands appendBytes:"\x1b\x45"
                   length:sizeof("\x1b\x45") - 1];            // Set Bold
    
    [commands appendData:[@" 101 發票金額 :\x09             330\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    [commands appendBytes:"\x1b\x46"
                   length:sizeof("\x1b\x46") - 1];            // Cancel Bold

    [commands appendData:[@"2014-01-15 13:00\n" dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];
    
    
    // 1D barcode example
    [commands appendBytes:"\x1b\x1d\x61\x01"
                   length:sizeof("\x1b\x1d\x61\x01") - 1];
    [commands appendBytes:"\x1b\x62\x34\x31\x32\x50"
                   length:sizeof("\x1b\x62\x34\x31\x32\x50") - 1];
    
    [commands appendBytes:"999999999\x1e\r\n"
                   length:sizeof("999999999\x1e\r\n") - 1];
    
    [commands appendBytes:"\x1b\x1d\x61\x30"
                   length:sizeof("\x1b\x1d\x61\x30") - 1];    // Alignment (Left)

    [commands appendData:[@"商品退換、贈品及停車兌換請持本聯。\n"
                           "9999999-9999999 999999-999999 9999\n"
                          dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5)]];

    [commands appendBytes:"\x1b\x64\x33"
                   length:sizeof("\x1b\x64\x33") - 1];        // Cut

    return commands;
}

+ (NSData *)sampleReceiptWithPaperWidth:(SMPaperWidth)paperWidth language:(SMLanguage)language kickDrawer:(BOOL)kickDrawer {
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
        case SMLanguageRussian:
            languageName = @"russian";
            break;
        case SMLanguageJapanese:
            languageName = @"japanese";
            break;
        case SMLanguageSimplifiedChinese:
            languageName = @"simplifiedChinese";
            break;
        case SMLanguageTraditionalChinese:
            languageName = @"traditionalChinese";
            break;
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
    }

    NSString *methodName = [NSString stringWithFormat:@"%@%@SampleReceipt", languageName, paperWidthName];
    SEL selector = NSSelectorFromString(methodName);
    if ([self respondsToSelector:selector] == NO) {
        return nil;
    }

    // Get receipt data
    NSData *receiptData = [self performSelector:selector];

    // Kick cash drawer
    NSMutableData *commands = [NSMutableData dataWithData:receiptData];
    if (kickDrawer) {
        [commands appendBytes:"\x07" length:sizeof("\x07") - 1];
    }


    return commands;
}

#pragma mark Sample Receipt (Raster)

+ (UIImage *)imageWithString:(NSString *)string font:(UIFont *)font width:(CGFloat)width
{
    CGSize size = CGSizeMake(width, 10000);
    float systemVersion = UIDevice.currentDevice.systemVersion.floatValue;
    
    CGSize messuredSize;
    if (systemVersion >= 7.0) {
        messuredSize = [string boundingRectWithSize:size
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                         attributes:@{NSFontAttributeName: font}
                                            context:nil].size;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        messuredSize = [string sizeWithFont:font constrainedToSize:size];
#pragma clang diagnostic pop
    }
	
	if ([UIScreen.mainScreen respondsToSelector:@selector(scale)]) {
		if (UIScreen.mainScreen.scale == 2.0) {
			UIGraphicsBeginImageContextWithOptions(messuredSize, NO, 1.0);
		} else {
			UIGraphicsBeginImageContext(messuredSize);
		}
	} else {
		UIGraphicsBeginImageContext(messuredSize);
	}
    
    CGContextRef ctr = UIGraphicsGetCurrentContext();
    UIColor *color = [UIColor whiteColor];
    [color set];
    
    CGRect rect = CGRectMake(0, 0, messuredSize.width + 1, messuredSize.height + 1);
    CGContextFillRect(ctr, rect);
    
    color = [UIColor blackColor];
    [color set];
    
    if (systemVersion >= 7.0) {
        [string drawInRect:rect withAttributes:@{NSFontAttributeName: font}];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [string drawInRect:rect withFont:font];
#pragma clang diagnostic pop
    }
    
    UIImage *imageToPrint = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return imageToPrint;
}

+ (void)PrintRasterSampleReceiptWithPortname:(NSString *)portName portSettings:(NSString *)portSettings paperWidth:(SMPaperWidth)paperWidth Language:(SMLanguage)language {
    switch (language) {
        case SMLanguageEnglish:
            switch (paperWidth) {
                case SMPaperWidth2inch:
                    [self PrintRasterSampleReceipt2InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth3inch:
                    [self PrintRasterSampleReceipt3InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth4inch:
                    [self PrintRasterSampleReceipt4InchWithPortname:portName portSettings:portSettings];
                    break;
            }
            break;
        case SMLanguageFrench:
            switch (paperWidth) {
                case SMPaperWidth2inch:
                    [self PrintRasterFrenchSampleReceipt2InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth3inch:
                    [self PrintRasterFrenchSampleReceipt3InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth4inch:
                    [self PrintRasterFrenchSampleReceipt4InchWithPortname:portName portSettings:portSettings];
                    break;
            }
            break;
        case SMLanguagePortuguese:
            switch (paperWidth) {
                case SMPaperWidth2inch:
                    [self PrintRasterPortugueseSampleReceipt2InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth3inch:
                    [self PrintRasterPortugueseSampleReceipt3InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth4inch:
                    [self PrintRasterPortugueseSampleReceipt4InchWithPortname:portName portSettings:portSettings];
                    break;
            }
            break;
        case SMLanguageSpanish:
            switch (paperWidth) {
                case SMPaperWidth2inch:
                    [self PrintRasterSpanishSampleReceipt2InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth3inch:
                    [self PrintRasterSpanishSampleReceipt3InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth4inch:
                    [self PrintRasterSpanishSampleReceipt4InchWithPortname:portName portSettings:portSettings];
                    break;
            }
            break;
        case SMLanguageRussian:
            switch (paperWidth) {
                case SMPaperWidth2inch:
                    [self PrintRasterRussianSampleReceipt2InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth3inch:
                    [self PrintRasterRussianSampleReceipt3InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth4inch:
                    [self PrintRasterRussianSampleReceipt4InchWithPortname:portName portSettings:portSettings];
                    break;
            }
            break;
        case SMLanguageJapanese:
            switch (paperWidth) {
                case SMPaperWidth2inch:
                    [self PrintRasterKanjiSampleReceipt2InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth3inch:
                    [self PrintRasterKanjiSampleReceipt3InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth4inch:
                    [self PrintRasterKanjiSampleReceipt4InchWithPortname:portName portSettings:portSettings];
                    break;
            }
            break;
        case SMLanguageSimplifiedChinese:
            switch (paperWidth) {
                case SMPaperWidth2inch:
                    [PrinterFunctions PrintRasterCHSSampleReceipt2InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth3inch:
                    [PrinterFunctions PrintRasterCHSSampleReceipt3InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth4inch:
                    [PrinterFunctions PrintRasterCHSSampleReceipt4InchWithPortname:portName portSettings:portSettings];
                    break;
            }
            break;
        case SMLanguageTraditionalChinese:
            switch (paperWidth) {
                case SMPaperWidth2inch:
                    [PrinterFunctions PrintRasterCHTSampleReceipt2InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth3inch:
                    [PrinterFunctions PrintRasterCHTSampleReceipt3InchWithPortname:portName portSettings:portSettings];
                    break;
                case SMPaperWidth4inch:
                    [PrinterFunctions PrintRasterCHTSampleReceipt4InchWithPortname:portName portSettings:portSettings];
                    break;
            }
            break;
    }
}

/**
 *  Print raster sample receipt (2inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterSampleReceipt2InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"   Star Clothing Boutique\r\n"
                             "        123 Star Road\r\n"
                             "      City, State 12345\r\n"
                             "\r\n"
                             "Date: MM/DD/YYYY   Time:HH:MM PM\r\n"
                             "-----------------------------\r\n"
                             "SALE\r\n"
                             "SKU       Description   Total\r\n"
                             "300678566 PLAIN T-SHIRT 10.99\n"
                             "300692003 BLACK DENIM   29.99\n"
                             "300651148 BLUE DENIM    29.99\n"
                             "300642980 STRIPED DRESS 49.99\n"
                             "30063847  BLACK BOOTS   35.99\n"
                             "\n"
                             "Subtotal               156.95\r\n"
                             "Tax                      0.00\r\n"
                             "-----------------------------\r\n"
                             "Total                 $156.95\r\n"
                             "-----------------------------\r\n"
                             "\r\n"
                             "Charge\r\n159.95\r\n"
                             "Visa XXXX-XXXX-XXXX-0123\r\n"
                             "Refunds and Exchanges\r\n"
                             "Within 30 days with receipt\r\n"
                             "And tags attached\r\n";
    
    CGFloat width = 384;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(11.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  Print raster sample receipt (3inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterSampleReceipt3InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"        Star Clothing Boutique\r\n"
                             "             123 Star Road\r\n"
                             "           City, State 12345\r\n"
                             "\r\n"
                             "Date: MM/DD/YYYY         Time:HH:MM PM\r\n"
                             "--------------------------------------\r\n"
                             "SALE\r\n"
                             "SKU            Description       Total\r\n" 
                             "300678566      PLAIN T-SHIRT     10.99\n"
                             "300692003      BLACK DENIM       29.99\n"
                             "300651148      BLUE DENIM        29.99\n"
                             "300642980      STRIPED DRESS     49.99\n"
                             "30063847       BLACK BOOTS       35.99\n"
                             "\n"
                             "Subtotal                        156.95\r\n"
                             "Tax                               0.00\r\n"
                             "--------------------------------------\r\n"
                             "Total                          $156.95\r\n"
                             "--------------------------------------\r\n"
                             "\r\n"
                             "Charge\r\n159.95\r\n"
                             "Visa XXXX-XXXX-XXXX-0123\r\n"
                             "Refunds and Exchanges\r\n"
                             "Within 30 days with receipt\r\n"
                             "And tags attached\r\n";
    
    CGFloat width = 576;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  Print raster sample receipt (4inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterSampleReceipt4InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"                   Star Clothing Boutique\r\n"
                             "                        123 Star Road\r\n"
                             "                      City, State 12345\r\n"
                             "\r\n" 
                             "Date: MM/DD/YYYY                            Time:HH:MM PM\r\n"
                             "---------------------------------------------------------\r\n"
                             "SALE\r\n"
                             "SKU                     Description                 Total\r\n" 
                             "300678566               PLAIN T-SHIRT               10.99\n"
                             "300692003               BLACK DENIM                 29.99\n"
                             "300651148               BLUE DENIM                  29.99\n"
                             "300642980               STRIPED DRESS               49.99\n"
                             "300638471               BLACK BOOTS                 35.99\n"
                             "\n"
                             "Subtotal                                           156.95\r\n"
                             "Tax                                                  0.00\r\n"
                             "---------------------------------------------------------\r\n"
                             "Total                                             $156.95\r\n"
                             "---------------------------------------------------------\r\n"
                             "\r\n"
                             "Charge\r\n159.95\r\n"
                             "Visa XXXX-XXXX-XXXX-0123\r\n"
                             "Refunds and Exchanges\r\n"
                             "Within 30 days with receipt\r\n"
                             "And tags attached\r\n";
    
    CGFloat width = 832;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(11.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster French sample receipt (2inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterFrenchSampleReceipt2InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"          ORANGE          \n"
                             "    36 AVENUE LA MOTTE    \n"
                             " PICQUET City, State 12345\n\n"
                             "--------------------------\n"
                             "Date: MM/DD/YYYY          \n"
                             "Time:HH:MM PM             \n"
                             "Boutique: OLUA23          \n"
                             "Caisse: 0001              \n"
                             "Conseiller: 002970        \n"
                             "Ticket: 3881              \n"
                             "--------------------------\n"
                             "Vous avez été servi par : \n"
                             "                     Souad\n"
                             "CAC IPHONE ORANGE         \n"
                             "3700615033581 1 X 19.99€  \n"
                             "                  19.99€  \n"
                             "dont contribution         \n"
                             " environnementale :       \n"
                             "CAC IPHONE ORANGE 0.01€   \n"
                             "--------------------------\n"
                             " 1 Piéce(s) Total : 19.99€\n\n"
                             "  Mastercard Visa : 19.99€\n"
                             "Taux TVA Montant H.T.     \n"
                             "     20%       16.66€     \n"
                             "T.V.A                     \n"
                             "3.33€                     \n"
                             "Merci de votre visite et. \n"
                             "à bientôt.                \n"
                             "Conservez votre ticket il \n"
                             "vous sera demandé pour    \n"
                             "tout échange.             \n";

    CGFloat width = 384;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];

    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];

    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster French sample receipt (3inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterFrenchSampleReceipt3InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"                ORANGE                \n"
                             "           36 AVENUE LA MOTTE         \n"
                             "        PICQUET City, State 12345     \n\n"
                             "--------------------------------------\n"
                             "     Date: MM/DD/YYYY    Time:HH:MM PM\n"
                             "        Boutique: OLUA23  Caisse: 0001\n"
                             "      Conseiller: 002970  Ticket: 3881\n"
                             "--------------------------------------\n"
                             "Vous avez été servi par : Souad       \n"
                             "CAC IPHONE ORANGE                     \n"
                             "3700615033581   1 X 19.99€      19.99€\n"
                             "dont contribution environnementale :  \n"
                             "CAC IPHONE ORANGE                0.01€\n"
                             "--------------------------------------\n"
                             "  1 Piéce(s)    Total :         19.99€\n\n"
                             "        Mastercard Visa  :      19.99€\n"
                             "          Taux TVA  Montant H.T. T.V.A\n"
                             "               20%       16.66€  3.33€\n"
                             "  Merci de votre visite et. à bientôt.\n"
                             "   Conservez votre ticket il vous sera\n"
                             "            demandé pour tout échange.\n";
    
    CGFloat width = 576;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster French sample receipt (4inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterFrenchSampleReceipt4InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"                        ORANGE                         \n"
                             "     36 AVENUE LA MOTTE PICQUET City, State 12345      \n\n"
                             "-------------------------------------------------------\n"
                             "                      Date: MM/DD/YYYY    Time:HH:MM PM\n"
                             "                  Boutique: OLUA23         Caisse: 0001\n"
                             "                Conseiller: 002970         Ticket: 3881\n"
                             "-------------------------------------------------------\n"
                             "Vous avez été servi par : Souad                        \n"
                             "CAC IPHONE ORANGE                                      \n"
                             "3700615033581      1  X  19.99€                  19.99€\n"
                             "dont contribution environnementale :                   \n"
                             "CAC IPHONE ORANGE                                 0.01€\n"
                             "-------------------------------------------------------\n"
                             "        1 Piéce(s)    Total :                    19.99€\n\n"
                             "        Mastercard Visa  :                       19.99€\n"
                             "                           Taux TVA  Montant H.T. T.V.A\n"
                             "                              20%         16.66€  3.33€\n"
                             "                   Merci de votre visite et. à bientôt.\n"
                             " Conservez votre ticket il vous sera demandé pour      \n"
                             " tout échange.                                         \n";
    
    CGFloat width = 832;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Portuguese sample receipt (2inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterPortugueseSampleReceipt2InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"COMERCIAL DE ALIMENTOS    \n"
                             "       CARREFOUR LTDA.    \n"
                             "Avenida Moyses Roysen,    \n"
                             "S/N Vila Guilherme        \n"
                             "Cep: 02049-010 – Sao Paulo\n"
                             "     – SP                 \n"
                             "CNPJ: 62.545.579/0013-69  \n"
                             "IE:110.819.138.118        \n"
                             "IM: 9.041.041-5           \n"
                             "--------------------------\n"
                             "MM/DD/YYYY HH:MM:SS       \n"
                             "CCF:133939 COO:227808     \n"
                             "--------------------------\n"
                             "CUPOM FISCAL              \n"
                             "--------------------------\n"
                             "01 CAFÉ DO PONTO TRAD A   \n"
                             "              1un F1 8,15)\n"
                             "02 CAFÉ DO PONTO TRAD A   \n"
                             "              1un F1 8,15)\n"
                             "03 CAFÉ DO PONTO TRAD A   \n"
                             "              1un F1 8,15)\n"
                             "04 AGU MIN NESTLE 510ML   \n"
                             "              1un F1 1,39)\n"
                             "05 AGU MIN NESTLE 510ML   \n"
                             "              1un F1 1,39)\n"
                             "--------------------------\n"
                             "TOTAL  R$            27,23\n"
                             "DINHEIROv            29,00\n\n"
                             "TROCO R$              1,77\n"
                             "Valor dos Tributos        \n"
                             "R$2,15(7,90%)             \n"
                             "ITEM(S) CINORADIS 5       \n"
                             "OP.:15326  PDV:9          \n"
                             "            BR,BF:93466   \n"
                             "OBRIGADO PERA PREFERENCIA.\n"
                             "VOLTE SEMPRE!             \n"
                             "SAC 0800 724 2822         \n"
                             "--------------------------\n"
                             "MD5:                      \n"
                             "fe028828a532a7dbaf4271155a\n"
                             "a4e2db                    \n"
                             "Calypso_CA CA.20.c13      \n"
                             " – Unisys Brasil          \n"
                             "--------------------------\n"
                             "DARUMA AUTOMAÇÃO   MACH 2 \n"
                             "ECF-IF VERSÃO:01,00,00    \n"
                             "ECF:093                   \n"
                             "Lj:0204 OPR:ANGELA JORGE  \n"
                             "DDDDDDDDDAEHFGBFCC        \n"
                             "MM/DD/YYYY HH:MM:SS       \n"
                             "FAB:DR0911BR000000275026  \n\n";
    
    CGFloat width = 384;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Portuguese sample receipt (3inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterPortugueseSampleReceipt3InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"         COMERCIAL DE ALIMENTOS        \n"
                             "            CARREFOUR LTDA.            \n"
                             "        Avenida Moyses Roysen,         \n"
                             "          S/N Vila Guilherme           \n"
                             "     Cep: 02049-010 – Sao Paulo – SP   \n"
                             "        CNPJ: 62.545.579/0013-69       \n"
                             "  IE:110.819.138.118    IM: 9.041.041-5\n"
                             "---------------------------------------\n"
                             "MM/DD/YYYY HH:MM:SS                    \n"
                             "CCF:133939   COO:227808                \n"
                             "---------------------------------------\n"
                             "CUPOM FISCAL                           \n"
                             "---------------------------------------\n"
                             "01  CAFÉ DO PONTO TRAD A  1un F1  8,15)\n"
                             "02  CAFÉ DO PONTO TRAD A  1un F1  8,15)\n"
                             "03  CAFÉ DO PONTO TRAD A  1un F1  8,15)\n"
                             "04  AGU MIN NESTLE 510ML  1un F1  1,39)\n"
                             "05  AGU MIN NESTLE 510ML  1un F1  1,39)\n"
                             "---------------------------------------\n"
                             "TOTAL  R$                         27,23\n"
                             "DINHEIROv                         29,00\n\n"
                             "TROCO R$                           1,77\n"
                             "Valor dos Tributos R$2,15(7,90%)       \n"
                             "ITEM(S) CINORADIS 5                    \n"
                             "OP.:15326  PDV:9  BR,BF:93466          \n"
                             "OBRIGADO PERA PREFERENCIA.             \n"
                             "VOLTE SEMPRE!    SAC 0800 724 2822     \n"
                             "---------------------------------------\n"
                             "MD5:  fe028828a532a7dbaf4271155aa4e2db \n"
                             "Calypso_CA CA.20.c13 – Unisys Brasil   \n"
                             "---------------------------------------\n"
                             "DARUMA AUTOMAÇÃO   MACH 2              \n"
                             "ECF-IF VERSÃO:01,00,00 ECF:093         \n"
                             "Lj:0204 OPR:ANGELA JORGE               \n"
                             "DDDDDDDDDAEHFGBFCC                     \n"
                             "MM/DD/YYYY HH:MM:SS                    \n"
                             "FAB:DR0911BR000000275026               \n\n";
    
    CGFloat width = 576;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 * This function print the Raster Portuguese sample receipt (4inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterPortugueseSampleReceipt4InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"          COMERCIAL DE ALIMENTOS CARREFOUR LTDA.         \n"
                             "         Avenida Moyses Roysen, S/N Vila Guilherme       \n"
                             "              Cep: 02049-010 – Sao Paulo – SP            \n"
                             "                  CNPJ: 62.545.579/0013-69               \n"
                             "                    IE:110.819.138.118    IM: 9.041.041-5\n"
                             "---------------------------------------------------------\n"
                             "              MM/DD/YYYY HH:MM:SS CCF:133939   COO:227808\n"
                             "---------------------------------------------------------\n"
                             "CUPOM FISCAL                                             \n"
                             "---------------------------------------------------------\n"
                             "01   CAFÉ DO PONTO TRAD A    1un F1                 8,15)\n"
                             "02   CAFÉ DO PONTO TRAD A    1un F1                 8,15)\n"
                             "03   CAFÉ DO PONTO TRAD A    1un F1                 8,15)\n"
                             "04   AGU MIN NESTLE 510ML    1un F1                 1,39)\n"
                             "05   AGU MIN NESTLE 510ML    1un F1                 1,39)\n"
                             "---------------------------------------------------------\n"
                             "TOTAL  R$                                           27,23\n"
                             "DINHEIROv                                           29,00\n\n"
                             "TROCO R$                                             1,77\n"
                             "Valor dos Tributos R$2,15(7,90%)                         \n"
                             "ITEM(S) CINORADIS 5                                      \n"
                             "OP.:15326  PDV:9  BR,BF:93466                            \n"
                             "OBRIGADO PERA PREFERENCIA.                               \n"
                             "                       VOLTE SEMPRE!    SAC 0800 724 2822\n"
                             "---------------------------------------------------------\n"
                             "                   MD5:  fe028828a532a7dbaf4271155aa4e2db\n"
                             "                     Calypso_CA CA.20.c13 – Unisys Brasil\n"
                             "---------------------------------------------------------\n"
                             "DARUMA AUTOMAÇÃO   MACH 2                                \n"
                             "ECF-IF VERSÃO:01,00,00 ECF:093                           \n"
                             "Lj:0204 OPR:ANGELA JORGE                                 \n"
                             "DDDDDDDDDAEHFGBFCC                                       \n"
                             "MM/DD/YYYY HH:MM:SS                                      \n"
                             "FAB:DR0911BR000000275026                                 \n\n";
    
    CGFloat width = 832;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Spanish sample receipt (2inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterSpanishSampleReceipt2InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
     NSString *textToPrint = @"     BAR RESTAURANT       \n"
                              "                   EL POZO\n"
                              "C/.ROCAFORT 187           \n"
                              "08029 BARCELONA           \n"
                              "NIF :X-3856907Z           \n"
                              "TEL :934199465            \n"
                              "--------------------------\n"
                              "MESA: 100 P: -            \n"
                              "    FECHA: YYYY-MM-DD     \n"
                              "CAN P/U DESCRIPCION  SUMA \n"
                              "--------------------------\n"
                              "3,00 JARRA CERVESA   12,00\n"
                              "1,60 COPA DE CERVESA  1,60\n"
                              "--------------------------\n"
                              "         SUB TOTAL : 13,60\n"
                              "TOTAL:         13,60 EUROS\n"
                              " NO:000018851 IVA INCLUIDO\n"
                              "                          \n"
                              "--------------------------\n"
                              "**GRACIAS POR SU VISITA!**\n";

    
    CGFloat width = 384;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Spanish sample receipt (3inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterSpanishSampleReceipt3InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint =  @"                        BAR RESTAURANT\n"
                              "                               EL POZO\n"
                              "C/.ROCAFORT 187                       \n"
                              "08029 BARCELONA                       \n"
                              "NIF :X-3856907Z                       \n"
                              "TEL :934199465                        \n"
                              "--------------------------------------\n"
                              "MESA: 100 P: - FECHA: YYYY-MM-DD      \n"
                              "CAN P/U DESCRIPCION  SUMA             \n"
                              "--------------------------------------\n"
                              "4 3,00 JARRA  CERVESA   12,00         \n"
                              "1 1,60 COPA DE CERVESA  1,60          \n"
                              "--------------------------------------\n"
                              "                     SUB TOTAL : 13,60\n"
                              "TOTAL:               13,60 EUROS      \n"
                              "NO: 000018851 IVA INCLUIDO            \n\n"
                              "--------------------------------------\n"
                              "**GRACIAS POR SU VISITA!**            \n\n";
    
    CGFloat width = 576;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Spanish sample receipt (4inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterSpanishSampleReceipt4InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"                                   BAR RESTAURANT EL POZO\n"
                             "                          C/.ROCAFORT 187 08029 BARCELONA\n"
                             "                          NIF :X-3856907Z  TEL :934199465\n"
                             "---------------------------------------------------------\n"
                             "MESA: 100 P: - FECHA: YYYY-MM-DD                         \n"
                             "CAN P/U DESCRIPCION  SUMA                                \n"
                             "---------------------------------------------------------\n"
                             "4    3,00    JARRA  CERVESA                         12,00\n"
                             "1    1,60    COPA DE CERVESA                         1,60\n"
                             "---------------------------------------------------------\n"
                             "                                  SUB TOTAL :       13,60\n"
                             "                                 TOTAL :      13,60 EUROS\n"
                             "NO: 000018851 IVA INCLUIDO                               \n\n"
                             "---------------------------------------------------------\n"
                             "                             ***GRACIAS POR SU VISITA!***\n\n";
                                
    CGFloat width = 832;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Russian sample receipt (2inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterRussianSampleReceipt2InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"          Р Е Л А К С       \n"
                             "          ООО “РЕЛАКС”      \n"
                             "СПб., Малая Балканская, д.  \n"
                             "38, лит. А                  \n\n"
                             "тел. 307-07-12              \n"
                             "РЕГ №322736     ИНН:123321  \n"
                             "01 Белякова И.А. КАССА:0020 \n"
                             "ОТД.01                      \n"
                             "ЧЕК НА ПРОДАЖУ  No 84373    \n"
                             "----------------------------\n"
                             " 1.Яблоки Айдаред, кг 144.50\n"
                             " 2.Соус соевый Sen So  36.40\n"
                             " 3.Соус томатный Клас  19.90\n"
                             " 4.Ребра свиные в.к м  78.20\n"
                             " 5.Масло подсол раф д 114.00\n"
                             " 6.Блокнот 10х14см сп 164.00\n"
                             " 7.Морс Северная Ягод  99.90\n"
                             " 8.Активия Биойогурт   43.40\n"
                             " 9.Бублики Украинские  26.90\n"
                             "10.Активия Биойогурт   43.40\n"
                             "11.Сахар-песок 1кг     58.40\n"
                             "12.Хлопья овсяные Ясн  38.40\n"
                             "13.Кинза 50г           39.90\n"
                             "14.Пемза “Сердечко” .Т 37.90\n"
                             "15.Приправа Santa Mar  47.90\n"
                             "16.Томаты слива Выбор 162.00\n"
                             "17.Бонд Стрит Ред Сел  56.90\n"
                             "----------------------------\n"
                             "----------------------------\n"
                             "ДИСКОНТНАЯ КАРТА            \n"
                             "            No:2440012489765\n"
                             "----------------------------\n"
                             "ИТОГО К ОПЛАТЕ = 1212.00    \n"
                             "НАЛИЧНЫЕ = 1212.00          \n"
                             "ВАША СКИДКА : 0.41          \n"
                             "ЦЕНЫ УКАЗАНЫ С УЧЕТОМ СКИДКИ\n\n"
                             "08-02-2015 09:49            \n"
                             "0254.013060400083213 #060127\n"
                             "СПАСИБО ЗА ПОКУПКУ !        \n\n"
                             "МЫ  ОТКРЫТЫ ЕЖЕДНЕВНО С 9 ДО\n"
                             "23 СОХРАНЯЙТЕ, ПОЖАЛУЙСТА , \n"
                             "ЧЕК                         \n";
    
    CGFloat width = 384;
    UIFont *font = [UIFont fontWithName:@"Menlo" size:(11.0 * 2)];
    if (UIDevice.currentDevice.systemVersion.floatValue < 7.0) {
        font = [UIFont fontWithName:@"Courier" size:(11.0 * 2)];
    }
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Russian sample receipt (3inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterRussianSampleReceipt3InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    
    NSString *textToPrint = @"      Р Е Л А К С   ООО “РЕЛАКС”      \n"
                             " СПб., Малая Балканская, д. 38, лит. А\n\n"
                             "тел. 307-07-12                        \n"
                             "РЕГ №322736     ИНН:123321            \n"
                             "01 Белякова И.А. КАССА: 0020 ОТД.01   \n"
                             "ЧЕК НА ПРОДАЖУ  No 84373              \n"
                             "--------------------------------------\n"
                             " 1. Яблоки Айдаред, кг          144.50\n"
                             " 2. Соус соевый Sen So           36.40\n"
                             " 3. Соус томатный Клас           19.90\n"
                             " 4. Ребра свиные в.к м           78.20\n"
                             " 5. Масло подсол раф д          114.00\n"
                             " 6. Блокнот 10х14см сп          164.00\n"
                             " 7. Морс Северная Ягод           99.90\n"
                             " 8. Активия Биойогурт            43.40\n"
                             " 9. Бублики Украинские           26.90\n"
                             "10. Активия Биойогурт            43.40\n"
                             "11. Сахар-песок 1кг              58.40\n"
                             "12. Хлопья овсяные Ясн           38.40\n"
                             "13. Кинза 50г                    39.90\n"
                             "14. Пемза “Сердечко” .Т          37.90\n"
                             "15. Приправа Santa Mar           47.90\n"
                             "16. Томаты слива Выбор          162.00\n"
                             "17. Бонд Стрит Ред Сел           56.90\n"
                             "--------------------------------------\n"
                             "--------------------------------------\n"
                             "ДИСКОНТНАЯ КАРТА      No:2440012489765\n"
                             "--------------------------------------\n"
                             "ИТОГО К ОПЛАТЕ = 1212.00              \n"
                             "НАЛИЧНЫЕ = 1212.00                    \n"
                             "ВАША СКИДКА : 0.41                    \n"
                             "ЦЕНЫ УКАЗАНЫ С УЧЕТОМ СКИДКИ          \n\n"
                             "08-02-2015 09:49  0254.0130604        \n"
                             "00083213 #060127                      \n"
                             "               СПАСИБО ЗА ПОКУПКУ !   \n\n"
                             "    МЫ  ОТКРЫТЫ ЕЖЕДНЕВНО С 9 ДО 23   \n"
                             "        СОХРАНЯЙТЕ, ПОЖАЛУЙСТА , ЧЕК  \n";
    
    CGFloat width = 576;
    UIFont *font = [UIFont fontWithName:@"Menlo" size:(12.0 * 2)];
    if (UIDevice.currentDevice.systemVersion.floatValue < 7.0) {
        font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    }
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Russian sample receipt (4inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterRussianSampleReceipt4InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    NSString *textToPrint = @"               Р Е Л А К С   ООО “РЕЛАКС”            \n"
                             "                СПб., Малая Балканская, д. 38, лит. А\n\n"
                             "тел. 307-07-12                                       \n"
                             "РЕГ №322736     ИНН:123321                           \n"
                             "01 Белякова И.А. КАССА: 0020 ОТД.01                  \n"
                             "ЧЕК НА ПРОДАЖУ  No 84373                             \n"
                             "-----------------------------------------------------\n"
                             " 1.      Яблоки Айдаред, кг                    144.50\n"
                             " 2.      Соус соевый Sen So                     36.40\n"
                             " 3.      Соус томатный Клас                     19.90\n"
                             " 4.      Ребра свиные в.к м                     78.20\n"
                             " 5.      Масло подсол раф д                    114.00\n"
                             " 6.      Блокнот 10х14см сп                    164.00\n"
                             " 7.      Морс Северная Ягод                     99.90\n"
                             " 8.      Активия Биойогурт                      43.40\n"
                             " 9.      Бублики Украинские                     26.90\n"
                             "10.      Активия Биойогурт                      43.40\n"
                             "11.      Сахар-песок 1кг                        58.40\n"
                             "12.      Хлопья овсяные Ясн                     38.40\n"
                             "13.      Кинза 50г                              39.90\n"
                             "14.      Пемза “Сердечко” .Т                    37.90\n"
                             "15.      Приправа Santa Mar                     47.90\n"
                             "16.      Томаты слива Выбор                    162.00\n"
                             "17.      Бонд Стрит Ред Сел                     56.90\n"
                             "-----------------------------------------------------\n"
                             "-----------------------------------------------------\n"
                             "ДИСКОНТНАЯ КАРТА                     No:2440012489765\n"
                             "-----------------------------------------------------\n"
                             "ИТОГО К ОПЛАТЕ = 1212.00                             \n"
                             "НАЛИЧНЫЕ = 1212.00                                   \n"
                             "ВАША СКИДКА : 0.41                                   \n"
                             "ЦЕНЫ УКАЗАНЫ С УЧЕТОМ СКИДКИ                         \n\n"
                             "08-02-2015 09:49  0254.0130604                       \n"
                             "00083213 #060127                                     \n"
                             "                                 СПАСИБО ЗА ПОКУПКУ !\n\n"
                             "                      МЫ  ОТКРЫТЫ ЕЖЕДНЕВНО С 9 ДО 23\n"
                             "                         СОХРАНЯЙТЕ, ПОЖАЛУЙСТА , ЧЕК\n";
    
    CGFloat width = 832;
    UIFont *font = [UIFont fontWithName:@"Menlo" size:(12.0 * 2)];
    if (UIDevice.currentDevice.systemVersion.floatValue < 7.0) {
        font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    }
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Kanji sample receipt (2inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterKanjiSampleReceipt2InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    char *sjisText = "　　　　　　スター電機\n"
                     "　　　　修理報告書　兼領収書\n"
                     "----------------------------------------------------\r\n"
                     "発行日時：YYYY年MM月DD日HH時MM分\n"
                     "TEL：054-347-XXXX\n\n"
                     "　　　　　ｲｹﾆｼ   ｼｽﾞｺ    ｻﾏ\n"
                     "　お名前：池西　静子　様\n"
                     "　御住所：静岡市清水区七ツ新屋\n"
                     "　　　　　５３６番地\n"
                     "　伝票番号：No.12345-67890\n\n"
                     "　この度は修理をご用命頂き有難うございます。\n"
                     " 今後も故障など発生した場合はお気軽にご連絡ください。\n"
                     "\n"
                     "品名／型名　 数量　　　金額\n"
                     "----------------------------------------------------\r\n"
                     "制御基板　　　１　　　１０，０００\n"
                     "操作スイッチ　１　　　　３，０００\n"
                     "パネル　　　　１　　　　２，０００\n"
                     "技術料　　　　１　　　１５，０００\n"
                     "出張費用　　　１　　　　５，０００\n"
                     "----------------------------------------------------\r\n"
                     "\n"
                     "　　　　　　　小計　¥ ３５，８００\n"
                     "　　　　　　　内税　¥ 　１，７９０\n"
                     "　　　　　　　合計　¥ ３７，５９０\n"
                     "\n"
                     "　お問合わせ番号　　12345-67890\n\n";
    
    NSString *textToPrint = [NSString stringWithCString:sjisText encoding:NSUTF8StringEncoding];
    
    CGFloat width = 384;

    UIFont *font = [UIFont fontWithName:@"STHeitiJ-Light" size:(11.0 * 2)];

    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Kanji sample receipt (3inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterKanjiSampleReceipt3InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    char *sjisText = "　　　　　　　　　　スター電機\n"
                     "　　　　　　　　修理報告書　兼領収書\n"
                     "------------------------------------------------------------------------\r\n"
                     "発行日時：YYYY年MM月DD日HH時MM分\n"
                     "TEL：054-347-XXXX\n\n"
                     "　　　　　ｲｹﾆｼ  ｼｽﾞｺ   ｻﾏ\n"
                     "　お名前：池西　静子　様\n"
                     "　御住所：静岡市清水区七ツ新屋\n"
                     "　　　　　５３６番地\n"
                     "　伝票番号：No.12345-67890\n\n"
                     "　この度は修理をご用命頂き有難うございます。\n"
                     " 今後も故障など発生した場合はお気軽にご連絡ください。\n"
                     "\n"
                     "品名／型名　　　　数量　　　金額　　　　　備考\n"
                     "------------------------------------------------------------------------\r\n"
                     "制御基板　　　　　　１　１０，０００　　　配達\n"
                     "操作スイッチ　　　　１　　３，８００　　　配達\n"
                     "パネル　　　　　　　１　　２，０００　　　配達\n"
                     "技術料　　　　　　　１　１５，０００\n"
                     "出張費用　　　　　　１　　５，０００\n"
                     "------------------------------------------------------------------------\r\n"
                     "\n"
                     "　　　　　　　　　　　　　小計　¥ ３５，８００\n"
                     "　　　　　　　　　　　　　内税　¥ 　１，７９０\n"
                     "　　　　　　　　　　　　　合計　¥ ３７，５９０\n"
                     "\n"
                     "　お問合わせ番号　　12345-67890\n\n";

    NSString *textToPrint = [NSString stringWithCString:sjisText encoding:NSUTF8StringEncoding];

    CGFloat width = 576;
    UIFont *font = [UIFont fontWithName:@"STHeitiJ-Light" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Kanji sample receipt (4inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterKanjiSampleReceipt4InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    char *sjisText = "　　　　　　　　　　　　　　　スター電機\n"
                     "　　　　　　　　　　　　　修理報告書　兼領収書\n"
                     "--------------------------------------------------------------------------------------------------------\r\n"
                     "発行日時：YYYY年MM月DD日HH時MM分\n"
                     "TEL：054-347-XXXX\n\n"
                     "　　　　　ｲｹﾆｼ  ｼｽﾞｺ   ｻﾏ\n"
                     "　お名前：池西　静子　様\n"
                     "　御住所：静岡市清水区七ツ新屋\n"
                     "　　　　　５３６番地\n"
                     "　伝票番号：No.12345-67890\n\n"
                     "　この度は修理をご用命頂き有難うございます。\n"
                     " 今後も故障など発生した場合はお気軽にご連絡ください。\n"
                     "\n"
                     "品名／型名　　　　　　　　　数量　　　　　　金額　　　　　　　　備考\n"
                     "--------------------------------------------------------------------------------------------------------\r\n"
                     "制御基板　　　　　　　　　　　１　　　　１０，０００　　　　　　配達\n"
                     "操作スイッチ　　　　　　　　　１　　　　　３，８００　　　　　　配達\n"
                     "パネル　　　　　　　　　　　　１　　　　　２，０００　　　　　　配達\n"
                     "技術料　　　　　　　　　　　　１　　　　１５，０００\n"
                     "出張費用　　　　　　　　　　　１　　　　　５，０００\n"
                     "--------------------------------------------------------------------------------------------------------\r\n"
                     "\n"
                     "　　　　　　　　　　　　　　　　　　　　　　　　小計　¥ ３５，８００\n"
                     "　　　　　　　　　　　　　　　　　　　　　　　　内税　¥ 　１，７９０\n"
                     "　　　　　　　　　　　　　　　　　　　　　　　　合計　¥ ３７，５９０\n"
                     "\n"
                     "　お問合わせ番号　　12345-67890\n\n";

    NSString *textToPrint = [NSString stringWithCString:sjisText encoding:NSUTF8StringEncoding];

    CGFloat width = 832;
    UIFont *font = [UIFont fontWithName:@"STHeitiJ-Light" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Simplified Chainese sample receipt (2inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterCHSSampleReceipt2InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    char *gb2312Text = "　  　　STAR便利店\n"
                       "           欢迎光临\n"
                       "\n"
                       "Unit 1906-08,19/F,Enterprise Square 2,\n"
                       "  3 Sheung Yuet Road, Kowloon Bay, KLN\n"
                       "\n"
                       "Tel: (852) 2795 2335\n"
                       "\n"
                       "货品名称            数量    价格\n"
                       "------------------------------\r\n"
                       "罐装可乐\n"
                       "* Coke              1     7.00\n"
                       "纸包柠檬茶\n"
                       "* Lemon Tea         2    10.00\n"
                       "热狗\n"
                       "* Hot Dog           1    10.00\n"
                       "薯片(50克装)\n"
                       "* Potato Chips(50g) 1    11.00\n"
                       "------------------------------\r\n"
                       "\n"
                       "               总　数 :  38.00\n"
                       "               现　金 :  38.00\n"
                       "               找　赎 :   0.00\n"
                       "\n"
                       "卡号码 Card No. :    88888888\n"
                       "卡余额 Remaining Val. : 88.00\n"
                       "机号　 Device No. :    1234F1\n"
                       "\n"
                       "DD/MM/YYYY HH:MM:SS\n"
                       "交易编号: 88888\n"
                       "\n"
                       "          收银机:001  收银员:180\n";
    
    NSString *textToPrint = [NSString stringWithCString:gb2312Text encoding:NSUTF8StringEncoding];
    
    CGFloat width = 384;
    
    UIFont *font = [UIFont fontWithName:@"Courier" size:(11.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Simplified Chainese sample receipt (3inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterCHSSampleReceipt3InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    char *gb2312Text = "　　　　　　  　　STAR便利店\n"
                       "                欢迎光临\n"
                       "\n"
                       "Unit 1906-08,19/F,Enterprise Square 2,\n"
                       "  3 Sheung Yuet Road, Kowloon Bay, KLN\n"
                       "\n"
                       "Tel: (852) 2795 2335\n"
                       "\n"
                       "货品名称                 数量   　  价格\n"
                       "---------------------------------------\r\n"
                       "罐装可乐\n"
                       "* Coke                   1        7.00\n"
                       "纸包柠檬茶\n"
                       "* Lemon Tea              2       10.00\n"
                       "热狗\n"
                       "* Hot Dog                1       10.00\n"
                       "薯片(50克装)\n"
                       "* Potato Chips(50g)      1       11.00\n"
                       "---------------------------------------\r\n"
                       "\n"
                       "                        总　数 :  38.00\n"
                       "                        现　金 :  38.00\n"
                       "                        找　赎 :   0.00\n"
                       "\n"
                       "卡号码 Card No.        :       88888888\n"
                       "卡余额 Remaining Val.  :       88.00\n"
                       "机号　 Device No.      :       1234F1\n"
                       "\n"
                       "DD/MM/YYYY   HH:MM:SS   交易编号: 88888\n"
                       "\n"
                       "          收银机:001  收银员:180\n";
    
    NSString *textToPrint = [NSString stringWithCString:gb2312Text encoding:NSUTF8StringEncoding];
    
    CGFloat width = 576;
    
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];

    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Simplified Chainese sample receipt (4inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterCHSSampleReceipt4InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    char *gb2312Text = "　　　　　　  　　         STAR便利店\n"
                       "                          欢迎光临\n"
                       "\n"
                       "     Unit 1906-08,19/F,Enterprise Square 2,\n"
                       "                3 Sheung Yuet Road, Kowloon Bay, KLN\n"
                       "\n"
                       "Tel: (852) 2795 2335\n"
                       "\n"
                       "货品名称                               数量          价格\n"
                       "---------------------------------------------------------\r\n"
                       "罐装可乐\n"
                       "* Coke                                 1            7.00\n"
                       "纸包柠檬茶\n"
                       "* Lemon Tea                            2           10.00\n"
                       "热狗\n"
                       "* Hot Dog                              1           10.00\n"
                       "薯片(50克装)\n"
                       "* Potato Chips(50g)                    1           11.00\n"
                       "---------------------------------------------------------\r\n"
                       "\n"
                       "                                          总　数 :  38.00\n"
                       "                                          现　金 :  38.00\n"
                       "                                          找　赎 :   0.00\n"
                       "\n"
                       "卡号码 Card No.        :       88888888\n"
                       "卡余额 Remaining Val.  :       88.00\n"
                       "机号　 Device No.      :       1234F1\n"
                       "\n"
                       "DD/MM/YYYY              HH:MM:SS          交易编号: 88888\n"
                       "\n"
                       "                   收银机:001  收银员:180\n";
    
    NSString *textToPrint = [NSString stringWithCString:gb2312Text encoding:NSUTF8StringEncoding];
    
    CGFloat width = 832;
    
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Traditional Chainese sample receipt (3inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterCHTSampleReceipt2InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    char *gig5Text = "　　　　Star Micronics\n"
                     "------------------------------\r\n"
                     "        電子發票證明聯\n"
                     "        103年01-02月\n"
                     "        EV-99999999\n"
                     "2014/01/15 13:00\n"
                     "隨機碼 : 9999      總計 : 999\n"
                     "賣　方 : 99999999\n"
                     "\n"
                     "商品退換請持本聯及銷貨明細表。\n"
                     "9999999-9999999 999999-999999 9999\n"
                     "\n"
                     "\n"
                     "        銷貨明細表 　(銷售)\n"
                     "     2014-01-15 13:00:02\n"
                     "\n"
                     "烏龍袋茶2g20入　      55 x2  110TX\n"
                     "茉莉烏龍茶2g20入      55 x2  110TX\n"
                     "天仁觀音茶2g*20　     55 x2  110TX\n"
                     "     小　　計 :　　          330\n"
                     "     總　　計 :　　          330\n"
                     "------------------------------\r\n"
                     "現　金　　　                 400\n"
                     "     找　　零 :　　           70\n"
                     " 101 發票金額 :　　          330\n"
                     "2014-01-15 13:00\n"
                     "\n"
                     "商品退換、贈品及停車兌換請持本聯。\n"
                     "9999999-9999999 999999-999999 9999\n";
    
    NSString *textToPrint = [NSString stringWithCString:gig5Text encoding:NSUTF8StringEncoding];
    
    CGFloat width = 384;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(11.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Traditional Chainese sample receipt (3inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterCHTSampleReceipt3InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    char *gig5Text = "　 　　　  　　Star Micronics\n"
                     "---------------------------------------\r\n"
                     "              電子發票證明聯\n"
                     "              103年01-02月\n"
                     "              EV-99999999\n"
                     "2014/01/15 13:00\n"
                     "隨機碼 : 9999      總計 : 999\n"
                     "賣　方 : 99999999\n"
                     "\n"
                     "商品退換請持本聯及銷貨明細表。\n"
                     "9999999-9999999 999999-999999 9999\n"
                     "\n"
                     "\n"
                     "         銷貨明細表 　(銷售)\n"
                     "                    2014-01-15 13:00:02\n"
                     "\n"
                     "烏龍袋茶2g20入　         55 x2    110TX\n"
                     "茉莉烏龍茶2g20入         55 x2    110TX\n"
                     "天仁觀音茶2g*20　        55 x2    110TX\n"
                     "     小　　計 :　　        330\n"
                     "     總　　計 :　　        330\n"
                     "---------------------------------------\r\n"
                     "現　金　　　               400\n"
                     "     找　　零 :　　         70\n"
                     " 101 發票金額 :　　        330\n"
                     "2014-01-15 13:00\n"
                     "\n"
                     "商品退換、贈品及停車兌換請持本聯。\n"
                     "9999999-9999999 999999-999999 9999\n";
    
    NSString *textToPrint = [NSString stringWithCString:gig5Text encoding:NSUTF8StringEncoding];
    
    CGFloat width = 576;
    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

/**
 *  This function print the Raster Traditional Chainese sample receipt (4inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)PrintRasterCHTSampleReceipt4InchWithPortname:(NSString *)portName portSettings:(NSString *)portSettings
{
    char *gig5Text = "　 　　　  　  　       Star Micronics\n"
                     "---------------------------------------------------------\r\n"
                     "                       電子發票證明聯\n"
                     "                       103年01-02月\n"
                     "                       EV-99999999\n"
                     "2014/01/15 13:00\n"
                     "隨機碼 : 9999      總計 : 999\n"
                     "賣　方 : 99999999\n"
                     "\n"
                     "商品退換請持本聯及銷貨明細表。\n"
                     "9999999-9999999 999999-999999 9999\n"
                     "\n"
                     "\n"
                     "                      銷貨明細表 　(銷售)\n"
                     "                                      2014-01-15 13:00:02\n"
                     "\n"
                     "烏龍袋茶2g20入　                   55 x2        110TX\n"
                     "茉莉烏龍茶2g20入                   55 x2        110TX\n"
                     "天仁觀音茶2g*20　                  55 x2        110TX\n"
                     "     小　　計 :　　                  330\n"
                     "     總　　計 :　　                  330\n"
                     "---------------------------------------------------------\r\n"
                     "現　金　　　                         400\n"
                     "     找　　零 :　　                   70\n"
                     " 101 發票金額 :　　                  330\n"
                     "2014-01-15 13:00\n"
                     "\n"
                     "商品退換、贈品及停車兌換請持本聯。\n"
                     "9999999-9999999 999999-999999 9999\n";
    
    NSString *textToPrint = [NSString stringWithCString:gig5Text encoding:NSUTF8StringEncoding];
    
    CGFloat width = 832;

    UIFont *font = [UIFont fontWithName:@"Courier" size:(12.0 * 2)];
    
    UIImage *imageToPrint = [self imageWithString:textToPrint font:font width:width];
    
    [PrinterFunctions PrintImageWithPortname:portName portSettings:portSettings imageToPrint:imageToPrint maxWidth:width compressionEnable:YES withDrawerKick:YES];
}

#pragma mark Sample Receipt (Line) - without drawer kick

/**
 *  This function print the sample receipt (3inch)
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
 */
+ (void)printSampleReceiptWithoutDrawerKickWithPortname:(NSString *)portName
                                           portSettings:(NSString *)portSettings
                                             paperWidth:(SMPaperWidth)paperWidth
                                           errorMessage:(NSMutableString *)message {
    NSData *commands = nil;

    switch (paperWidth) {
        case SMPaperWidth2inch:
            commands = [self english2inchSampleReceipt];
            break;
        case SMPaperWidth3inch:
            commands = [self english3inchSampleReceipt];
            break;
        case SMPaperWidth4inch:
            commands = [self english4inchSampleReceipt];
            break;
    }
    
    [self sendCommand:commands portName:portName portSettings:portSettings timeoutMillis:10000 errorMessage:message];
    
}

+ (void)sendCommand:(NSData *)commandsToPrint portName:(NSString *)portName portSettings:(NSString *)portSettings
      timeoutMillis:(u_int32_t)timeoutMillis errorMessage:(NSMutableString *)message
{
    int commandSize = (int)commandsToPrint.length;
    unsigned char *dataToSentToPrinter = (unsigned char *)malloc(commandSize);
    [commandsToPrint getBytes:dataToSentToPrinter length:commandSize];
    
    SMPort *starPort = nil;
    @try
    {
        starPort = [SMPort getPort:portName :portSettings :timeoutMillis];
        if (starPort == nil)
        {
            [message appendString:@"Fail to Open Port.\nRefer to \"getPort API\" in the manual."];
            return;
        }
        
        StarPrinterStatus_2 status;
        [starPort beginCheckedBlock:&status :2];
        if (status.offline == SM_TRUE) {
            [message appendString:@"Printer is offline"];
            return;
        }
        
        struct timeval endTime;
        gettimeofday(&endTime, NULL);
        endTime.tv_sec += 30;
        
        int totalAmountWritten = 0;
        while (totalAmountWritten < commandSize)
        {
            int remaining = commandSize - totalAmountWritten;
            int amountWritten = [starPort writePort:dataToSentToPrinter :totalAmountWritten :remaining];
            totalAmountWritten += amountWritten;
            
            struct timeval now;
            gettimeofday(&now, NULL);
            if (now.tv_sec > endTime.tv_sec) {
                break;
            }
        }
        
        if (totalAmountWritten < commandSize) {
            [message appendString:@"Write port timed out"];
            return;
        }

        [starPort endCheckedBlock:&status :2];
        if (status.offline == SM_TRUE) {
            [message appendString:@"Printer is offline"];
            return;
        }
    }
    @catch (PortException *exception)
    {
        [message appendString:@"Write port timed out"];
    }
    @finally
    {
        free(dataToSentToPrinter);
        [SMPort releasePort:starPort];
    }
}

#pragma mark MSR

/**
 *  This function shows how to read the MCR data(credit card) of a portable printer.
 *  The function first puts the printer into MCR read mode, then asks the user to swipe a credit card
 *  This object then acts as a delegate for the UIAlertView.  See alert view responce for seeing how to read the MCR
 *  data
 *  one a card has been swiped.
 *  The user can cancel the MCR mode or the read the printer
 *
 *  @param  portName        Port name to use for communication. This should be (TCP:<IP Address>), (BT:<iOS Port Name>),
 *                          or (BLE:<Device Name>).
 *  @param  portSettings    Set following settings
 *                          - Desktop USB Printer + Apple AirPort: @"9100" - @"9109" (Port Number)
 *                          - Portable Printer (Star Line Mode)  : @"portable"
 *                          - Others                             : @"" (blank)
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

    }
}

/**
 *  This is the responce function for reading MCR data.
 *  This will eather cancel the MCR function or read the data
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
        }
        @catch (PortException *exception)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Card Data"
                                                            message:@"Failed to read port"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
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
    }
    
    [SMPort releasePort:starPort];
}


#pragma mark Bluetooth Setting
/*
+ (SMBluetoothManager *)loadBluetoothSetting:(NSString *)portName portSettings:(NSString *)portSettings {
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Error"
                                                     message:@""
                                                    delegate:nil
                                           cancelButtonTitle:nil
                                           otherButtonTitles:@"OK", nil] autorelease];
    
    if (([portName.lowercaseString hasPrefix:@"bt:"] == NO) &&
        ([portName.lowercaseString hasPrefix:@"ble:"] == NO)) {
        alert.message = @"This function is available via the bluetooth interface only.";
        [alert show];
        return nil;
    }

    SMDeviceType deviceType;
    SMPrinterType printerType = [AppDelegate parsePortSettings:portSettings];
    if (printerType == SMPrinterTypeDesktopPrinterStarLine) {
        deviceType = SMDeviceTypeDesktopPrinter;
    } else {
        deviceType = SMDeviceTypePortablePrinter;
    }

    SMBluetoothManager *manager = [[[SMBluetoothManager alloc] initWithPortName:portName
                                                                     deviceType:deviceType] autorelease];
    if (manager == nil) {
        alert.message = @"initWithPortName:deviceType: is failure.";
        [alert show];
        return nil;
    }
    
    if ([manager open] == NO) {
        alert.message = @"open is failure.";
        [alert show];
        return nil;
    }
    
    if ([manager loadSetting] == NO) {
        alert.message = @"loadSetting is failure.";
        [alert show];
        [manager close];
        return nil;
    }
    
    [manager close];
    
    return manager;
}*/

#pragma mark diconnect bluetooth

+ (void)disconnectPort:(NSString *)portName portSettings:(NSString *)portSettings timeout:(u_int32_t)timeout {
    SMPort *port = [SMPort getPort:portName :portSettings :timeout];
    if (port == nil) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Fail to Open Port.\nRefer to \"getPort API\" in the manual."
                                                        message:@""
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];

        return;
    }
    
    BOOL result = [port disconnect];
    if (result == NO) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Fail to Disconnect"
                                                        message:@""
                                                       delegate:nil
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"OK", nil];
        [alert show];
        return;
    }
    
    [SMPort releasePort:port];
}

@end
