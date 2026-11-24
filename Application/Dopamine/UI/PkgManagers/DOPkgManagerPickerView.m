//
//  DOPkgManagerPickerView.m
//  Dopamine
//
//  Created by tomt000 on 08/02/2024.
//

#import "DOPkgManagerPickerView.h"
#import "DOAppSwitch.h"
#import "DOUIManager.h"
#import "DOActionMenuButton.h"
#import "DOGlobalAppearance.h"
#import "DOSigningManager.h"
#import "DOCreditsViewController.h"

@interface DOPkgManagerPickerView ()

@property (nonatomic, retain) DOActionMenuButton *continueAction;
@property (nonatomic, weak) UIViewController *viewController;

@end

#define PADDING_BTN_CONTINUE 30

@implementation DOPkgManagerPickerView

-(id)initWithCallback:(void (^)(BOOL))callback {
    return [self initWithCallback:callback viewController:nil];
}

-(id)initWithCallback:(void (^)(BOOL))callback viewController:(UIViewController *)vc {
    self = [super init];
    if (self) {
        self.viewController = vc;

        UIStackView *switchStack = [[UIStackView alloc] init];
        switchStack.axis = UILayoutConstraintAxisHorizontal;
        switchStack.translatesAutoresizingMaskIntoConstraints = NO;

        [self addSubview:switchStack];

        [NSLayoutConstraint activateConstraints:@[
            [switchStack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [switchStack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant: -([DOGlobalAppearance isHomeButtonDevice] ? 0 : 10)]
        ]];

        NSArray *packageManagers = [[DOUIManager sharedInstance] availablePackageManagers];
        [packageManagers enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *manager = (NSDictionary *)obj;
            DOAppSwitch *appSwitch = [[DOAppSwitch alloc] initWithIcon:[UIImage imageNamed:manager[@"Icon"]] title:manager[@"Display Name"]];
            appSwitch.selected = [[[DOUIManager sharedInstance] enabledPackageManagerKeys] containsObject:manager[@"Key"]];
            appSwitch.onSwitch = ^(BOOL enabled) {
                [[DOUIManager sharedInstance] setPackageManager:manager[@"Key"] enabled:enabled];
                [self updateButtonState];
            };

            appSwitch.translatesAutoresizingMaskIntoConstraints = NO;
            [switchStack addArrangedSubview:appSwitch];

            [NSLayoutConstraint activateConstraints:@[
                [appSwitch.widthAnchor constraintEqualToConstant:110],
                [appSwitch.heightAnchor constraintEqualToConstant:110]
            ]];
        }];

        // ESing app switch
        UIImage *esignIcon = [UIImage systemImageNamed:@"signature" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:40 weight:UIImageSymbolWeightRegular]];
        DOAppSwitch *esignSwitch = [[DOAppSwitch alloc] initWithIcon:esignIcon title:@"ESing"];
        esignSwitch.selected = NO;
        esignSwitch.onSwitch = ^(BOOL enabled) {
            [self startESigning];
        };
        esignSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        [switchStack addArrangedSubview:esignSwitch];
        [NSLayoutConstraint activateConstraints:@[
            [esignSwitch.widthAnchor constraintEqualToConstant:110],
            [esignSwitch.heightAnchor constraintEqualToConstant:110]
        ]];

        UILabel *title = [[UILabel alloc] init];
        title.text = DOLocalizedString(@"Status_Title_Select_Package_Managers");
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont systemFontOfSize:24 weight:UIFontWeightMedium];
        title.textAlignment = NSTextAlignmentCenter;
        title.translatesAutoresizingMaskIntoConstraints = NO;

        [self addSubview:title];

        [NSLayoutConstraint activateConstraints:@[
            [title.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [title.bottomAnchor constraintEqualToAnchor:switchStack.topAnchor constant:-30]
        ]];

        UILabel *tooltip = [[UILabel alloc] init];
        tooltip.text = DOLocalizedString(@"Select_Package_Managers_Install_Message");
        tooltip.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        tooltip.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
        tooltip.textAlignment = NSTextAlignmentCenter;
        tooltip.numberOfLines = 3;
        tooltip.translatesAutoresizingMaskIntoConstraints = NO;

        [self addSubview:tooltip];

        [NSLayoutConstraint activateConstraints:@[
            [tooltip.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [tooltip.topAnchor constraintEqualToAnchor:switchStack.bottomAnchor constant:15],
            [tooltip.widthAnchor constraintEqualToAnchor:switchStack.widthAnchor multiplier:1.25]
        ]];

        self.continueAction = [DOActionMenuButton buttonWithAction:[UIAction actionWithTitle:DOLocalizedString(@"Continue") image:[UIImage systemImageNamed:@"arrow.right" withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:@"continue" handler:^(__kindof UIAction * _Nonnull action) {
            callback(TRUE);
        }] chevron:NO];
        self.continueAction.layer.cornerRadius = 14.0;
        self.continueAction.layer.cornerCurve = kCACornerCurveContinuous;
        self.continueAction.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.continueAction.translatesAutoresizingMaskIntoConstraints = NO;

        [self addSubview:self.continueAction];


        [NSLayoutConstraint activateConstraints:@[
            [self.continueAction.heightAnchor constraintEqualToConstant:50],
            [self.continueAction.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-PADDING_BTN_CONTINUE - ([DOGlobalAppearance isHomeButtonDevice] ? 0 : 10)],
            [self.continueAction.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:PADDING_BTN_CONTINUE],
            [self.continueAction.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-PADDING_BTN_CONTINUE]
        ]];



        [self updateButtonState];

    }
    return self;
}

- (UIViewController *)presentingViewController
{
    if (self.viewController) return self.viewController;
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}

- (void)startESigning
{
    UIViewController *vc = [self presentingViewController];
    if (!vc) return;

    DOSigningManager *sm = [DOSigningManager sharedManager];
    if (![sm hasRequiredCertificates]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Missing Certificates" message:@"Upload your .p12 certificate and .mobileprovision in Credits before using ESing." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Go to Credits" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [vc.navigationController pushViewController:[[DOCreditsViewController alloc] init] animated:YES];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [vc presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *passwordAlert = [UIAlertController alertControllerWithTitle:@"P12 Password" message:@"Enter the password for your .p12 certificate" preferredStyle:UIAlertControllerStyleAlert];
    [passwordAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Password";
        textField.secureTextEntry = YES;
    }];
    [passwordAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [passwordAlert addAction:[UIAlertAction actionWithTitle:@"Sign" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *password = passwordAlert.textFields.firstObject.text ?: @"";
        [self performESigningWithPassword:password];
    }]];
    [vc presentViewController:passwordAlert animated:YES completion:nil];
}

- (void)performESigningWithPassword:(NSString *)password
{
    UIViewController *vc = [self presentingViewController];
    if (!vc) return;

    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:@"ESigning..." message:@"Preparing..." preferredStyle:UIAlertControllerStyleAlert];
    [vc presentViewController:progressAlert animated:YES completion:nil];

    [[DOSigningManager sharedManager] startESignFromViewController:vc p12Password:password progress:^(NSString *status, float progress) {
        progressAlert.message = [NSString stringWithFormat:@"%@ (%.0f%%)", status, progress * 100];
    } completion:^(BOOL success, NSError *error) {
        [progressAlert dismissViewControllerAnimated:YES completion:^{
            if (!success) {
                UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:@"ESigning Failed" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [errAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [vc presentViewController:errAlert animated:YES completion:nil];
            }
        }];
    }];
}

- (void)updateButtonState
{
    NSArray *selected = [[DOUIManager sharedInstance] enabledPackageManagerKeys];
    self.continueAction.enabled = selected.count > 0;
    self.continueAction.backgroundColor = [UIColor colorWithWhite:1.0 alpha:selected.count > 0 ? 0.2 : 0.1];
}

@end
