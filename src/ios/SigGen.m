//
//  SigGen.m
//  Route Trax - News
//
//  Created by Mac on 7/15/15.
//
//

#import "SigGen.h"

@implementation SigGen

- (UIFont *)getSelectedFont:(int)multiple;
{
    NSArray *array_font;
    NSArray *array_fontStyle;
    
    array_font = [[NSArray alloc] initWithArray:[UIFont familyNames]];
    array_fontStyle = [[NSArray alloc] initWithArray:[UIFont fontNamesForFamilyName:array_font[0]]];
    
    int fontIndex = (int)1;
    if (fontIndex > array_fontStyle.count - 1) {
        fontIndex = (int)array_fontStyle.count - 1;
    }
    
    NSString *fontName = array_fontStyle[fontIndex];
    
    double f = [UIFont labelFontSize];
    NSString *fontSize1 = [NSString stringWithFormat:@"%02.2f", f];
    //uitextfield_textsize.text = fontSize;
    
    double fontSize = [fontSize1 floatValue];
    fontSize *= multiple;
    
    UIFont *font = [UIFont fontWithName:fontName size:fontSize];
    
    return font;
}

- (UIImage *)drawSignatureBMP : (NSArray *)verticesPassed {
    

    CGRect shp = [self boundFromFrame:verticesPassed];
    
    CGSize size = CGSizeMake(shp.size.width,shp.size.height);
    float maxWidth = [self maxWidth:verticesPassed];
    maxWidth = shp.size.width - maxWidth;
    maxWidth = maxWidth / 2;
    
//    CGSize size = CGSizeMake(576, 300);
    UIGraphicsBeginImageContext(size);
    
    CGContextRef ctr = UIGraphicsGetCurrentContext();
    UIColor *color = [UIColor whiteColor];
    [color set];
    
    CGRect rect = CGRectMake(0, 0, shp.size.width, shp.size.height);
    CGContextFillRect(ctr, rect);
    
    color = [UIColor blackColor];
    [color set];
    
    
    CGContextRef ctxt = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctxt, 5);
    

    CGContextMoveToPoint(ctxt, 0 , 0);
    CGContextAddLineToPoint(ctxt, shp.size.width , 0 );
    CGContextAddLineToPoint(ctxt, shp.size.width, shp.size.height );
    CGContextAddLineToPoint(ctxt, 0 , shp.size.height);
    CGContextAddLineToPoint(ctxt, 0 , 0);
    
    CGPoint standPoint;
    
    bool bFirst = YES;

    for (NSArray *vertice in verticesPassed) {
        for(id ver in vertice)
        {
            standPoint.x = [[ver objectAtIndex:0] floatValue];
            standPoint.y = [[ver objectAtIndex:1] floatValue];
            if(bFirst)
            {
                CGContextMoveToPoint(ctxt, standPoint.x + maxWidth , standPoint.y);
                bFirst = NO;
                
            }
            else
            {
                CGContextAddLineToPoint(ctxt, standPoint.x + maxWidth, standPoint.y );
            }
        }
    }

    CGContextSetLineCap(ctxt, kCGLineCapRound);
    
    CGContextStrokePath(ctxt);
    
    UIImage *imageToPrint = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    return imageToPrint;

}

-(CGRect)boundFromFrame:(NSArray*)verticesPassed
{
    float top,left,right,bottom;
    bool bFirst = YES;
    
    CGPoint standPoint;
    
    for (NSArray *vertice in verticesPassed) {
        for(id ver in vertice)
        {
            standPoint.x = [[ver objectAtIndex:0] floatValue];
            standPoint.y = [[ver objectAtIndex:1] floatValue];
            if(bFirst)
            {
                left = right = standPoint.x;
                top = bottom = standPoint.y;
                
                bFirst = NO;
                
            }
            else
            {
                if (standPoint.x < left) left = standPoint.x;
                if (standPoint.x > right) right = standPoint.x;
                if (standPoint.y < top) top = standPoint.y;
                if (standPoint.y > bottom) bottom = standPoint.y;
            }
        }
    }
    
    if(right < 576) right = 576;
    if(bottom < 300) bottom = 300;
    return CGRectMake(left, top, right, bottom);
//    return CGRectMake(left, top, right - left, bottom-top);
//return CGRectMake(0, 0, 576, 300);
}
-(float)maxWidth:(NSArray*)verticesPassed
{
    float width;
    bool bFirst = YES;
    
    CGPoint standPoint;
    
    for (NSArray *vertice in verticesPassed) {
        for(id ver in vertice)
        {
            standPoint.x = [[ver objectAtIndex:0] floatValue];
            standPoint.y = [[ver objectAtIndex:1] floatValue];
            if(bFirst)
            {
                width = standPoint.x;
                bFirst = NO;
                
            }
            else
            {
                if (standPoint.x > width) width = standPoint.x;
            }
        }
    }
    return width;
}
@end
