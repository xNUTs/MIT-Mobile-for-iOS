#import <UIKit/UIKit.h>
#import "SMCalloutView.h"

@class MITMartyResource;

@interface MITMartyMapViewController : UIViewController

@property (nonatomic, strong) NSArray *resources;
@property (nonatomic, strong) SMCalloutView *calloutView;
@property (nonatomic) UIEdgeInsets mapEdgeInsets;

- (UIBarButtonItem *)userLocationButton;
- (void)setResources:(NSArray *)resources animated:(BOOL)animated;
- (void)showCalloutForResource:(MITMartyResource *)resource;

@end
