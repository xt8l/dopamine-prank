//
//  Jailbreaker.m
//  Dopamine
//
//  Fake version - simulates jailbreak with realistic-looking log messages
//

#import "DOJailbreaker.h"
#import "DOEnvironmentManager.h"
#import "DOUIManager.h"
#import "DOPreferenceManager.h"
#import <sys/sysctl.h>

@implementation DOJailbreaker

- (BOOL)contiguousMappingWorkaroundNeeded
{
    return NO;
}

- (void)applyContiguousMappingWorkaround
{
    // No-op
}

- (void)runWithError:(NSError **)errOut didRemoveJailbreak:(BOOL *)didRemove showLogs:(BOOL *)showLogs
{
    *didRemove = NO;
    *showLogs = YES;

    BOOL removeJailbreakEnabled = [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"removeJailbreakEnabled" fallback:NO];

    if (removeJailbreakEnabled) {
        [[DOEnvironmentManager sharedManager] setJailbroken:NO withVersion:nil];
        *didRemove = YES;
        return;
    }

    DOUIManager *uiManager = [DOUIManager sharedInstance];

    // Phase 1: Kernel exploitation
    [uiManager sendLog:@"Downloading Kernel" debug:NO];
    [NSThread sleepForTimeInterval:0.8 + (arc4random_uniform(500) / 1000.0)];

    [uiManager sendLog:@"Patchfinding kernel" debug:NO];
    [NSThread sleepForTimeInterval:1.2 + (arc4random_uniform(800) / 1000.0)];

    [uiManager sendLog:@"Initializing exploit" debug:NO];
    [NSThread sleepForTimeInterval:0.3];

    [uiManager sendLog:@"Launching kexploitd" debug:NO];
    [NSThread sleepForTimeInterval:0.5 + (arc4random_uniform(300) / 1000.0)];

    [uiManager sendLog:@"Exploiting kernel vulnerability" debug:NO];
    [NSThread sleepForTimeInterval:1.0 + (arc4random_uniform(1000) / 1000.0)];

    [uiManager sendLog:@"Gaining kernel r/w primitives" debug:NO];
    [NSThread sleepForTimeInterval:0.6 + (arc4random_uniform(400) / 1000.0)];

    // Phase 2: Bypasses
    NSArray *bypasses = @[@"AMFI", @"PAC", @"PPL", @"KTRR", @"KPP", @"APRR"];
    for (NSString *bypass in bypasses) {
        [uiManager sendLog:[NSString stringWithFormat:@"Bypassing %@", bypass] debug:NO];
        [NSThread sleepForTimeInterval:0.2 + (arc4random_uniform(400) / 1000.0)];
    }

    // Phase 3: Post-exploitation
    [uiManager sendLog:@"Getting root" debug:NO];
    [NSThread sleepForTimeInterval:0.3];

    [uiManager sendLog:@"Unsandboxing" debug:NO];
    [NSThread sleepForTimeInterval:0.4];

    [uiManager sendLog:@"Platformizing" debug:NO];
    [NSThread sleepForTimeInterval:0.3];

    [uiManager sendLog:@"Loading BaseBin trustcache" debug:NO];
    [NSThread sleepForTimeInterval:0.5];

    // Phase 4: Bootstrap
    [uiManager sendLog:@"Preparing bootstrap" debug:NO];
    [NSThread sleepForTimeInterval:0.8 + (arc4random_uniform(500) / 1000.0)];

    [uiManager sendLog:@"Installing packages" debug:NO];
    [NSThread sleepForTimeInterval:1.0 + (arc4random_uniform(800) / 1000.0)];

    [uiManager sendLog:@"Injecting launchd" debug:NO];
    [NSThread sleepForTimeInterval:0.4];

    [uiManager sendLog:@"Initializing environment protection" debug:NO];
    [NSThread sleepForTimeInterval:0.3];

    [uiManager sendLog:@"Cleaning up exploits" debug:NO];
    [NSThread sleepForTimeInterval:0.3];

    [uiManager sendLog:@"Rebooting Userspace" debug:NO];
    [NSThread sleepForTimeInterval:0.5];

    // Mark as "jailbroken" in NSUserDefaults
    NSString *version = [[DOEnvironmentManager sharedManager] appVersion];
    [[DOEnvironmentManager sharedManager] setJailbroken:YES withVersion:version];

    // Success - no error
    *errOut = nil;
}

- (void)finalize
{
    // Simulate reboot by exiting the app
    // When user reopens, it will show "Jailbroken" state
    exit(0);
}

@end
