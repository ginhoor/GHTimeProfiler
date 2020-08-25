//
//  GHTimeProfilerLog.m
//  CommercialVehiclePlatform
//
//  Created by JunhuaShao on 2019/4/2.
//  Copyright © 2019 JunhuaShao. All rights reserved.
//

#import "GHTimeProfilerLog.h"

@implementation GHTimeProfilerLog

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    _createDate = [NSDate date].timeIntervalSince1970;
}

- (NSString *)description
{
    NSMutableString *str = [NSMutableString string];
    [str appendFormat:@"depth:%2d ", (int)_callDepth];
    [str appendFormat:@"(%6.2fms)", _timeCost * 1000.0];
    for (NSUInteger i = 0; i < _callDepth; i++) {
        [str appendString:@"  "];
    }
    [str appendFormat:@" %s[%@ %@]", (_isClassMethod ? "+" : "-"), _className, _methodName];
    return str;
}



@end
