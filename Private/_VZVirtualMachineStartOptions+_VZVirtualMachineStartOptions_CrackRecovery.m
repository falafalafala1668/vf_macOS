//
//  _VZVirtualMachineStartOptions+_VZVirtualMachineStartOptions_CrackRecovery.m
//  vfnogui_macOS
//
//  Created by Mianmian on 2021/12/9.
//

@import Virtualization;
#import "JRSwizzle.h"

@interface _VZVirtualMachineStartOptions : NSObject

- (BOOL)bootMacOSRecovery;
- (BOOL)stopInIBootStage1;
- (BOOL)forceDFU;

@end

@implementation _VZVirtualMachineStartOptions (CrackRecovery)

+ (void)load {
    [self jr_swizzleMethod:@selector(forceDFU) withMethod:@selector(new_forceDFU) error:nil];
    [self jr_swizzleMethod:@selector(bootMacOSRecovery) withMethod:@selector(new_bootMacOSRecovery) error:nil];
}

- (BOOL)new_bootMacOSRecovery {
    return YES;
}

- (BOOL)new_forceDFU {
    return YES;
}

@end
