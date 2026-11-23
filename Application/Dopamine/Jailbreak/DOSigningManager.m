#import "DOSigningManager.h"
#import "DOZipHelper.h"
#import <Security/Security.h>

static NSString *const kIPADownloadURL = @"https://drive.google.com/uc?export=download&id=17idQjaWf5YhWJOWuusSI4QSnBhW56VRo";

@implementation DOSigningManager

+ (instancetype)sharedManager {
    static DOSigningManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

#pragma mark - Paths

- (NSString *)documentsDirectory {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
}

- (NSString *)p12Path {
    return [[self documentsDirectory] stringByAppendingPathComponent:@"signing.p12"];
}

- (NSString *)mobileprovisionPath {
    return [[self documentsDirectory] stringByAppendingPathComponent:@"signing.mobileprovision"];
}

- (NSString *)p12NamePath {
    return [[self documentsDirectory] stringByAppendingPathComponent:@".p12name"];
}

- (NSString *)mobileprovisionNamePath {
    return [[self documentsDirectory] stringByAppendingPathComponent:@".mpname"];
}

#pragma mark - Certificate Management

- (BOOL)hasP12 {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self p12Path]];
}

- (BOOL)hasMobileprovision {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self mobileprovisionPath]];
}

- (BOOL)hasRequiredCertificates {
    return [self hasP12] && [self hasMobileprovision];
}

- (void)saveP12FromURL:(NSURL *)url {
    [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    [url stopAccessingSecurityScopedResource];
    if (data) {
        [data writeToFile:[self p12Path] atomically:YES];
        [url.lastPathComponent writeToFile:[self p12NamePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (void)saveMobileprovisionFromURL:(NSURL *)url {
    [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    [url stopAccessingSecurityScopedResource];
    if (data) {
        [data writeToFile:[self mobileprovisionPath] atomically:YES];
        [url.lastPathComponent writeToFile:[self mobileprovisionNamePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (void)removeP12 {
    [[NSFileManager defaultManager] removeItemAtPath:[self p12Path] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[self p12NamePath] error:nil];
}

- (void)removeMobileprovision {
    [[NSFileManager defaultManager] removeItemAtPath:[self mobileprovisionPath] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[self mobileprovisionNamePath] error:nil];
}

- (NSString *)p12DisplayName {
    NSString *name = [NSString stringWithContentsOfFile:[self p12NamePath] encoding:NSUTF8StringEncoding error:nil];
    return name ?: @"signing.p12";
}

- (NSString *)mobileprovisionDisplayName {
    NSString *name = [NSString stringWithContentsOfFile:[self mobileprovisionNamePath] encoding:NSUTF8StringEncoding error:nil];
    return name ?: @"signing.mobileprovision";
}

#pragma mark - Mobileprovision Parsing

- (NSDictionary *)parseMobileprovision:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;

    // Find the XML plist embedded in the CMS envelope
    NSString *content = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSRange plistStart = [content rangeOfString:@"<?xml"];
    NSRange plistEnd = [content rangeOfString:@"</plist>"];
    if (plistStart.location == NSNotFound || plistEnd.location == NSNotFound) return nil;

    NSRange plistRange = NSMakeRange(plistStart.location, plistEnd.location + plistEnd.length - plistStart.location);
    NSString *plistString = [content substringWithRange:plistRange];
    NSData *plistData = [plistString dataUsingEncoding:NSUTF8StringEncoding];

    return [NSPropertyListSerialization propertyListWithData:plistData options:0 format:nil error:nil];
}

- (NSString *)bundleIdFromMobileprovision:(NSDictionary *)plist {
    NSDictionary *entitlements = plist[@"Entitlements"];
    NSString *appId = entitlements[@"application-identifier"];
    if (!appId) return nil;
    // Strip team ID prefix: "TEAMID.com.example.app" -> "com.example.app"
    NSRange dotRange = [appId rangeOfString:@"."];
    if (dotRange.location != NSNotFound && dotRange.location + 1 < appId.length) {
        NSString *bundleId = [appId substringFromIndex:dotRange.location + 1];
        if ([bundleId isEqualToString:@"*"]) return nil; // wildcard
        return bundleId;
    }
    return nil;
}

#pragma mark - ESigning

- (void)startESignFromViewController:(UIViewController *)vc
                          p12Password:(NSString *)password
                             progress:(void(^)(NSString *status, float progress))progressBlock
                           completion:(void(^)(BOOL success, NSError *error))completionBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *err = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"esign"];
        [fm removeItemAtPath:tmpDir error:nil];
        [fm createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:nil];

        // Step 1: Verify P12
        dispatch_async(dispatch_get_main_queue(), ^{ progressBlock(@"Verifying certificate...", 0.05); });

        NSData *p12Data = [NSData dataWithContentsOfFile:[self p12Path]];
        if (!p12Data) {
            err = [NSError errorWithDomain:@"DOSign" code:1 userInfo:@{NSLocalizedDescriptionKey: @"P12 certificate not found"}];
            dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(NO, err); });
            return;
        }

        NSDictionary *options = @{(__bridge NSString *)kSecImportExportPassphrase: password ?: @""};
        CFArrayRef items = NULL;
        OSStatus status = SecPKCS12Import((__bridge CFDataRef)p12Data, (__bridge CFDictionaryRef)options, &items);
        if (status != errSecSuccess || !items || CFArrayGetCount(items) == 0) {
            if (items) CFRelease(items);
            err = [NSError errorWithDomain:@"DOSign" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid P12 password or certificate"}];
            dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(NO, err); });
            return;
        }
        if (items) CFRelease(items);

        // Step 2: Parse mobileprovision
        dispatch_async(dispatch_get_main_queue(), ^{ progressBlock(@"Reading provisioning profile...", 0.10); });

        NSDictionary *provisionPlist = [self parseMobileprovision:[self mobileprovisionPath]];
        if (!provisionPlist) {
            err = [NSError errorWithDomain:@"DOSign" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Invalid provisioning profile"}];
            dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(NO, err); });
            return;
        }

        NSString *newBundleId = [self bundleIdFromMobileprovision:provisionPlist];

        // Step 3: Download IPA
        dispatch_async(dispatch_get_main_queue(), ^{ progressBlock(@"Downloading IPA...", 0.15); });

        NSString *ipaPath = [tmpDir stringByAppendingPathComponent:@"app.ipa"];
        NSURL *downloadURL = [NSURL URLWithString:kIPADownloadURL];

        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);

        __block NSError *downloadError = nil;
        NSURLSessionDownloadTask *task = [session downloadTaskWithURL:downloadURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *dlError) {
            if (dlError || !location) {
                downloadError = dlError ?: [NSError errorWithDomain:@"DOSign" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Download failed"}];
            } else {
                [fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:ipaPath] error:&downloadError];
            }
            dispatch_semaphore_signal(sem);
        }];
        [task resume];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

        if (downloadError) {
            dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(NO, downloadError); });
            return;
        }

        // Check if we got an HTML page (Google Drive confirmation)
        NSData *ipaHead = [NSData dataWithContentsOfFile:ipaPath options:NSDataReadingMappedIfSafe error:nil];
        if (ipaHead.length > 4) {
            const char *headBytes = ipaHead.bytes;
            if (headBytes[0] == '<' || (headBytes[0] == '\n' && headBytes[1] == '<')) {
                // Got HTML - try to extract confirm link
                NSString *html = [[NSString alloc] initWithData:ipaHead encoding:NSUTF8StringEncoding];
                if (html) {
                    NSString *confirmURL = [self extractGDriveConfirmURL:html fileId:@"17idQjaWf5YhWJOWuusSI4QSnBhW56VRo"];
                    if (confirmURL) {
                        dispatch_async(dispatch_get_main_queue(), ^{ progressBlock(@"Confirming download...", 0.25); });
                        [fm removeItemAtPath:ipaPath error:nil];

                        __block NSError *confirmError = nil;
                        NSURLSessionDownloadTask *confirmTask = [session downloadTaskWithURL:[NSURL URLWithString:confirmURL] completionHandler:^(NSURL *loc, NSURLResponse *resp, NSError *dlErr) {
                            if (dlErr || !loc) {
                                confirmError = dlErr ?: [NSError errorWithDomain:@"DOSign" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Confirmed download failed"}];
                            } else {
                                [fm moveItemAtURL:loc toURL:[NSURL fileURLWithPath:ipaPath] error:&confirmError];
                            }
                            dispatch_semaphore_signal(sem);
                        }];
                        [confirmTask resume];
                        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

                        if (confirmError) {
                            dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(NO, confirmError); });
                            return;
                        }
                    }
                }
            }
        }

        // Step 4: Unzip IPA
        dispatch_async(dispatch_get_main_queue(), ^{ progressBlock(@"Extracting IPA...", 0.40); });

        NSString *extractDir = [tmpDir stringByAppendingPathComponent:@"extracted"];
        if (![DOZipHelper unzipFileAtPath:ipaPath toDirectory:extractDir error:&err]) {
            dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(NO, err); });
            return;
        }

        // Find the .app directory inside Payload
        NSString *payloadDir = [extractDir stringByAppendingPathComponent:@"Payload"];
        NSArray *contents = [fm contentsOfDirectoryAtPath:payloadDir error:nil];
        NSString *appDir = nil;
        for (NSString *item in contents) {
            if ([item hasSuffix:@".app"]) {
                appDir = [payloadDir stringByAppendingPathComponent:item];
                break;
            }
        }

        if (!appDir) {
            err = [NSError errorWithDomain:@"DOSign" code:5 userInfo:@{NSLocalizedDescriptionKey: @"No .app found in IPA"}];
            dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(NO, err); });
            return;
        }

        // Step 5: Replace mobileprovision
        dispatch_async(dispatch_get_main_queue(), ^{ progressBlock(@"Injecting provisioning profile...", 0.55); });

        NSString *embeddedMPPath = [appDir stringByAppendingPathComponent:@"embedded.mobileprovision"];
        [fm removeItemAtPath:embeddedMPPath error:nil];
        [fm copyItemAtPath:[self mobileprovisionPath] toPath:embeddedMPPath error:&err];

        // Step 6: Update bundle ID if needed
        if (newBundleId) {
            dispatch_async(dispatch_get_main_queue(), ^{ progressBlock(@"Updating bundle identifier...", 0.60); });

            NSString *infoPlistPath = [appDir stringByAppendingPathComponent:@"Info.plist"];
            NSMutableDictionary *infoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistPath];
            if (infoPlist) {
                infoPlist[@"CFBundleIdentifier"] = newBundleId;
                [infoPlist writeToFile:infoPlistPath atomically:YES];
            }
        }

        // Step 7: Remove existing code signature (let signing tool handle it)
        dispatch_async(dispatch_get_main_queue(), ^{ progressBlock(@"Preparing for signing...", 0.70); });

        NSString *codeSignDir = [appDir stringByAppendingPathComponent:@"_CodeSignature"];
        [fm removeItemAtPath:codeSignDir error:nil];

        // Step 8: Repackage IPA
        dispatch_async(dispatch_get_main_queue(), ^{ progressBlock(@"Repackaging IPA...", 0.80); });

        NSString *signedIpaPath = [tmpDir stringByAppendingPathComponent:@"signed.ipa"];
        if (![DOZipHelper createZipAtPath:signedIpaPath fromDirectory:extractDir error:&err]) {
            dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(NO, err); });
            return;
        }

        // Step 9: Copy to Documents for sharing
        dispatch_async(dispatch_get_main_queue(), ^{ progressBlock(@"Finalizing...", 0.95); });

        NSString *outputPath = [[self documentsDirectory] stringByAppendingPathComponent:@"ESigned.ipa"];
        [fm removeItemAtPath:outputPath error:nil];
        [fm copyItemAtPath:signedIpaPath toPath:outputPath error:&err];

        // Cleanup temp
        [fm removeItemAtPath:tmpDir error:nil];

        if (err) {
            dispatch_async(dispatch_get_main_queue(), ^{ completionBlock(NO, err); });
            return;
        }

        // Step 10: Present share sheet
        dispatch_async(dispatch_get_main_queue(), ^{
            progressBlock(@"Done!", 1.0);

            NSURL *ipaURL = [NSURL fileURLWithPath:outputPath];
            UIActivityViewController *shareVC = [[UIActivityViewController alloc] initWithActivityItems:@[ipaURL] applicationActivities:nil];
            shareVC.popoverPresentationController.sourceView = vc.view;
            shareVC.popoverPresentationController.sourceRect = CGRectMake(vc.view.bounds.size.width / 2, vc.view.bounds.size.height / 2, 0, 0);
            [vc presentViewController:shareVC animated:YES completion:^{
                completionBlock(YES, nil);
            }];
        });
    });
}

- (NSString *)extractGDriveConfirmURL:(NSString *)html fileId:(NSString *)fileId {
    // Look for confirmation token in Google Drive virus scan page
    NSRange confirmRange = [html rangeOfString:@"confirm="];
    if (confirmRange.location != NSNotFound) {
        NSUInteger start = confirmRange.location + confirmRange.length;
        NSRange endRange = [html rangeOfString:@"&" options:0 range:NSMakeRange(start, MIN(100, html.length - start))];
        if (endRange.location == NSNotFound) {
            endRange = [html rangeOfString:@"\"" options:0 range:NSMakeRange(start, MIN(100, html.length - start))];
        }
        if (endRange.location != NSNotFound) {
            NSString *token = [html substringWithRange:NSMakeRange(start, endRange.location - start)];
            return [NSString stringWithFormat:@"https://drive.google.com/uc?export=download&confirm=%@&id=%@", token, fileId];
        }
    }
    // Fallback: direct download with confirm=t
    return [NSString stringWithFormat:@"https://drive.google.com/uc?export=download&confirm=t&id=%@", fileId];
}

@end
