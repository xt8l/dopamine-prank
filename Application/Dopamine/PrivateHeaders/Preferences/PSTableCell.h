#import <UIKit/UIKit.h>
#import "PSSpecifier.h"

@interface PSTableCell : UITableViewCell

@property (nonatomic, retain) PSSpecifier *specifier;

- (id)initWithStyle:(long long)style reuseIdentifier:(id)reuseIdentifier specifier:(PSSpecifier *)specifier;
- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier;

@end
