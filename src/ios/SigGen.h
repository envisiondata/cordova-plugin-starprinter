//
//  SigGen.h
//  Route Trax - News
//
//  Created by Mac on 7/15/15.
//
//

#ifndef Route_Trax___News_SigGen_h
#define Route_Trax___News_SigGen_h



#endif

@interface SigGen {
}-(CGRect)boundFromFrame:(NSArray*)verticesPassed;
- (UIImage *)drawSignatureBMP : (NSArray *)verticesPassed;
- (UIFont *)getSelectedFont:(int)multiple;
-(float)maxWidth:(NSArray*)verticesPassed;
@end

