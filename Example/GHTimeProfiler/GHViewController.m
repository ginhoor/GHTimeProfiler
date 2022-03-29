//
//  GHViewController.m
//  GHTimeProfiler
//
//  Created by Shaojunhua on 08/25/2020.
//  Copyright (c) 2020 Shaojunhua. All rights reserved.
//

#import "GHViewController.h"
#import <GHRunloopObserver.h>
#import <GHCPUObserver.h>

@interface GHViewController ()

@end

@implementation GHViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [[GHRunloopObserver sharedInstance] start];
    [[GHCPUObserver sharedInstance] start];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (int i = 0; i < 100000; i++) {
            UIView *v =  [[UIView alloc] init];
            [self.view addSubview:v];
        }
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i < 1000000; i++) {
            NSObject *obj = [[NSObject alloc] init];
        }
    });
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
