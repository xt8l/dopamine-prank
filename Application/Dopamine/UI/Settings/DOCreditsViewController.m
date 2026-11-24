#import "DOCreditsViewController.h"
#import "DOLicenseViewController.h"
#import "DOUIManager.h"
#import "DOEnvironmentManager.h"
#import "DOSigningManager.h"
#import <Preferences/PSSpecifier.h>
#ifdef __IPHONE_14_0
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#endif

@interface DOCreditsViewController ()
@property (nonatomic) BOOL pickingP12;
@end

@implementation DOCreditsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (id)specifiers
{
    if(_specifiers == nil) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Credits" target:self];

        PSSpecifier *headerSpecifier = _specifiers[0];
        [headerSpecifier setProperty:[NSString stringWithFormat:@"Dopamine %@ - %@", [DOEnvironmentManager sharedManager].appVersionDisplayString, DOLocalizedString(@"Menu_Credits_Title")] forKey:@"title"];

        [self updateCertificateStatus];
    }
    return _specifiers;
}

- (void)updateCertificateStatus
{
    DOSigningManager *sm = [DOSigningManager sharedManager];
    for (PSSpecifier *spec in _specifiers) {
        NSString *key = [spec propertyForKey:@"key"];
        if ([key isEqualToString:@"uploadP12"]) {
            if ([sm hasP12]) {
                [spec setProperty:[NSString stringWithFormat:@"✓ %@", [sm p12DisplayName]] forKey:@"title"];
            } else {
                [spec setProperty:@"Upload P12 Certificate" forKey:@"title"];
            }
        } else if ([key isEqualToString:@"uploadMP"]) {
            if ([sm hasMobileprovision]) {
                [spec setProperty:[NSString stringWithFormat:@"✓ %@", [sm mobileprovisionDisplayName]] forKey:@"title"];
            } else {
                [spec setProperty:@"Upload Provisioning Profile" forKey:@"title"];
            }
        }
    }
}

- (void)openSourceCode
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/opa334/Dopamine"] options:@{} completionHandler:nil];
}

- (void)openDiscord
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://discord.gg/jb"] options:@{} completionHandler:nil];
}

- (void)openLicense
{
    [self.navigationController pushViewController:[[DOLicenseViewController alloc] init] animated:YES];
}

#pragma mark - Certificate Upload

- (void)uploadP12Certificate
{
    self.pickingP12 = YES;
    [self presentDocumentPickerForType:@"p12"];
}

- (void)uploadMobileprovision
{
    self.pickingP12 = NO;
    [self presentDocumentPickerForType:@"mobileprovision"];
}

- (void)presentDocumentPickerForType:(NSString *)extension
{
    UIDocumentPickerViewController *picker;
#ifdef __IPHONE_14_0
    if (@available(iOS 14.0, *)) {
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData, UTTypeItem]];
    } else
#endif
    {
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data", @"public.item"] inMode:UIDocumentPickerModeImport];
    }
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
    NSURL *url = urls.firstObject;
    if (!url) return;

    DOSigningManager *sm = [DOSigningManager sharedManager];
    if (self.pickingP12) {
        [sm saveP12FromURL:url];
    } else {
        [sm saveMobileprovisionFromURL:url];
    }

    [self updateCertificateStatus];
    [self reloadSpecifiers];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    // No action needed
}

#pragma mark - Remove Jailbreak

- (void)removeJailbreak
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Remove Jailbreak" message:@"This will reset the jailbreak status. The app will close." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"fakeJailbroken"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"fakeJailbrokenVersion"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        exit(0);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
