//
//  EnvironmentManager.m
//  Dopamine
//
//  Fake version - uses NSUserDefaults to simulate jailbreak state
//

#import "DOEnvironmentManager.h"
#import "DOUIManager.h"
#import "DOPreferenceManager.h"
#import <sys/utsname.h>
#import <sys/sysctl.h>

@implementation DOEnvironmentManager

+ (instancetype)sharedManager
{
    static DOEnvironmentManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[DOEnvironmentManager alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _isJailbroken = [defaults boolForKey:@"fakeJailbroken"];
        _jailbrokenVersion = [defaults stringForKey:@"fakeJailbrokenVersion"];
    }
    return self;
}

- (NSString *)nightlyHash
{
    return nil;
}

- (NSString *)appVersion
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (NSString *)appVersionDisplayString
{
    return [self appVersion];
}

- (NSString *)versionSupportString
{
    return @"iOS 15.0 - 27.3 (All Devices)";
}

- (BOOL)isInstalledThroughTrollStore
{
    return NO;
}

- (BOOL)isJailbroken
{
    return _isJailbroken;
}

- (BOOL)isJailbrokenWithOtherJailbreak
{
    return NO;
}

- (BOOL)isBootstrapped
{
    return _isJailbroken;
}

- (NSString *)jailbrokenVersion
{
    if (!_isJailbroken) return nil;
    return _jailbrokenVersion;
}

- (NSString *)systemVersion
{
    return [[UIDevice currentDevice] systemVersion];
}

- (BOOL)isSupported
{
    return YES;
}

- (BOOL)isArm64e
{
    cpu_subtype_t cpusubtype = 0;
    size_t len = sizeof(cpusubtype);
    if (sysctlbyname("hw.cpusubtype", &cpusubtype, &len, NULL, 0) == -1) return NO;
    return (cpusubtype & ~CPU_SUBTYPE_MASK) == CPU_SUBTYPE_ARM64E;
}

- (BOOL)isSPTM
{
    return NO;
}

- (BOOL)isPACBypassRequired
{
    return NO;
}

- (BOOL)isPPLBypassRequired
{
    return NO;
}

- (void)setJailbroken:(BOOL)jailbroken withVersion:(NSString *)version
{
    _isJailbroken = jailbroken;
    _jailbrokenVersion = version;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:jailbroken forKey:@"fakeJailbroken"];
    if (version) {
        [defaults setObject:version forKey:@"fakeJailbrokenVersion"];
    }
    [defaults synchronize];
}

- (void)respring
{
    exit(0);
}

- (void)rebootUserspace
{
    exit(0);
}

- (void)reboot
{
    exit(0);
}

- (BOOL)isJailbreakHidden
{
    return NO;
}

- (BOOL)isTweakInjectionEnabled
{
    return [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"tweakInjectionEnabled" fallback:YES];
}

- (void)setTweakInjectionEnabled:(BOOL)enabled
{
    [[DOPreferenceManager sharedManager] setPreferenceValue:@(enabled) forKey:@"tweakInjectionEnabled"];
}

- (void)deleteBootstrap
{
    [self setJailbroken:NO withVersion:nil];
}

- (void)changeMobilePassword:(NSString *)newPassword
{
    // No-op in fake version
}

- (void)refreshJailbreakApps
{
    // No-op in fake version
}

- (NSError *)updateBootLogo
{
    return nil;
}

- (BOOL)isIDownloadEnabled
{
    return [[DOPreferenceManager sharedManager] boolPreferenceValueForKey:@"idownloadEnabled" fallback:NO];
}

- (void)setIDownloadLoaded:(BOOL)loaded needsUnsandbox:(BOOL)needsUnsandbox
{
    // No-op in fake version
}

- (void)rebuildIconCache
{
    // No-op
}

- (NSError *)reinstallPackageManagers
{
    return nil;
}

- (NSError *)updateEnvironment
{
    return nil;
}

- (void)updateJailbreakFromTIPA:(NSString *)path
{
    // No-op in fake version
}

@end
