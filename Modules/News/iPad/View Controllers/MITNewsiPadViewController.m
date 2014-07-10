#import "MITNewsiPadViewController.h"
#import "MITNewsPadLayout.h"
#import "MITNewsModelController.h"
#import "MITNewsStory.h"
#import "MITNewsCategory.h"
#import "MITNewsStoryCollectionViewCell.h"
#import "MITNewsConstants.h"
#import "MIT_MobileAppDelegate.h"
#import "MITCoreDataController.h"
#import "MITNewsStoryViewController.h"
#import "MITNewsSearchController.h"

#import "MITNewsListViewController.h"
#import "MITNewsGridViewController.h"
#import "MITMobile.h"
#import "MITCoreData.h"

#import "MITNewsStoriesDataSource.h"
#import "MITAdditions.h"

@interface MITNewsiPadViewController (NewsDataSource) <MITNewsStoryDataSource,MITNewsStoryDelegate>
@property (nonatomic,strong) NSString *searchQuery;
@property (nonatomic,strong) NSOrderedSet *searchResults;

- (BOOL)canLoadMoreItems;
- (void)loadMoreItems:(void(^)(NSError *error))block;
- (void)reloadItems:(void(^)(NSError *error))block;

- (void)loadDataSources:(void(^)(NSError*))completion;
@end

@interface MITNewsiPadViewController ()
@property (nonatomic, weak) IBOutlet UIView *containerView;
@property (nonatomic, weak) IBOutlet MITNewsGridViewController *gridViewController;
@property (nonatomic, weak) IBOutlet MITNewsListViewController *listViewController;
@property (nonatomic, strong) MITNewsSearchController *searchController;

@property (nonatomic, readonly, weak) UIViewController *activeViewController;
@property (nonatomic, getter=isSearching) BOOL searching;

#pragma mark Data Source
@property (nonatomic,copy) NSArray *categories;
@property (nonatomic,copy) NSArray *dataSources;
@end

@implementation MITNewsiPadViewController {
    BOOL _isTransitioningToPresentationStyle;
}

@synthesize activeViewController = _activeViewController;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

    }
    return self;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.gridViewController.collectionView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = YES;
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.showsFeaturedStories = YES;
    self.containerView.backgroundColor = [UIColor mit_backgroundColor];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (!self.activeViewController) {
        if ([self supportsPresentationStyle:MITNewsPresentationStyleGrid]) {
            [self setPresentationStyle:MITNewsPresentationStyleGrid animated:animated];
        } else {
            [self setPresentationStyle:MITNewsPresentationStyleList animated:animated];
        }
    }

    [self.navigationController setNavigationBarHidden:NO animated:animated];

    [self reloadItems:^(NSError *error) {
        if (error) {
            DDLogWarn(@"update failed; %@",error);
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Dynamic Properties
- (NSManagedObjectContext*)managedObjectContext
{
    if (!_managedObjectContext) {
        _managedObjectContext = [[MITCoreDataController defaultController] mainQueueContext];
    }

    return _managedObjectContext;
}

- (MITNewsGridViewController*)gridViewController
{
    MITNewsGridViewController *gridViewController = _gridViewController;

    if (![self supportsPresentationStyle:MITNewsPresentationStyleGrid]) {
        return nil;
    } else if (!gridViewController) {
        gridViewController = [[MITNewsGridViewController alloc] init];
        gridViewController.delegate = self;
        gridViewController.dataSource = self;
        _gridViewController = gridViewController;
    }

    return gridViewController;
}

- (MITNewsListViewController*)listViewController
{
    MITNewsListViewController *listViewController = _listViewController;

    if (![self supportsPresentationStyle:MITNewsPresentationStyleList]) {
        return nil;
    } else if (!listViewController) {
        listViewController = [[MITNewsListViewController alloc] init];
        listViewController.delegate = self;
        listViewController.dataSource = self;
        _listViewController = listViewController;
    }
    
    return listViewController;
}

- (void)setPresentationStyle:(MITNewsPresentationStyle)style
{
    [self setPresentationStyle:style animated:NO];
}

#pragma mark UI Actions
- (MITNewsSearchController *)searchController
{
    if(!_searchController) {
        MITNewsSearchController *searchController = [[MITNewsSearchController alloc] init];
        searchController.stories = self.stories;
        searchController.delegate = self;
        _searchController = searchController;
    }

    return _searchController;
}
- (IBAction)searchButtonWasTriggered:(UIBarButtonItem *)sender
{
    
}
- (void)setPresentationStyle:(MITNewsPresentationStyle)style animated:(BOOL)animated
{
    NSAssert([self supportsPresentationStyle:style], @"presentation style %d is not supported on this device", style);

    if (![self supportsPresentationStyle:style]) {
        return;
    } else if ((_presentationStyle != style) || !self.activeViewController) {
        _presentationStyle = style;

        // Figure out which view controllers we are going to be
        // transitioning from/to.
        UIViewController *fromViewController = self.activeViewController;
        UIViewController *toViewController = nil;
        if (_presentationStyle == MITNewsPresentationStyleGrid) {
            toViewController = self.gridViewController;
        } else {
            toViewController = self.listViewController;
        }

        const CGRect viewFrame = self.containerView.bounds;
        fromViewController.view.frame = viewFrame;
        toViewController.view.frame = viewFrame;

        const NSTimeInterval animationDuration = (animated ? 0.25 : 0);
        _isTransitioningToPresentationStyle = YES;
        _activeViewController = toViewController;
        if (!fromViewController) {
            [self addChildViewController:toViewController];

            [UIView transitionWithView:self.containerView
                              duration:animationDuration
                               options:0
                            animations:^{
                                [self.containerView addSubview:toViewController.view];
                            } completion:^(BOOL finished) {
                                _isTransitioningToPresentationStyle = NO;
                                [toViewController didMoveToParentViewController:self];
                            }];
        } else {
            [fromViewController willMoveToParentViewController:nil];
            [self addChildViewController:toViewController];

            [self transitionFromViewController:fromViewController
                              toViewController:toViewController
                                      duration:animationDuration
                                       options:0
                                    animations:nil
                                    completion:^(BOOL finished) {
                                        _isTransitioningToPresentationStyle = NO;
                                        [toViewController didMoveToParentViewController:self];
                                        [fromViewController removeFromParentViewController];
                                    }];
        }
    }
}

#pragma mark Utility Methods
- (BOOL)supportsPresentationStyle:(MITNewsPresentationStyle)style
{
    if (style == MITNewsPresentationStyleList) {
        return YES;
    } else if (style == MITNewsPresentationStyleGrid) {
        const CGFloat minimumWidthForGrid = 768.;
        const CGFloat boundsWidth = CGRectGetWidth(self.view.bounds);

        return (boundsWidth >= minimumWidthForGrid);
    }

    return NO;
}

#pragma mark UI Actions
- (IBAction)searchButtonWasTriggered:(UIBarButtonItem *)sender
{
    
}

- (IBAction)showStoriesAsGrid:(UIBarButtonItem *)sender
{
    self.presentationStyle = MITNewsPresentationStyleGrid;
}

- (IBAction)showStoriesAsList:(UIBarButtonItem *)sender
{
    self.presentationStyle = MITNewsPresentationStyleList;
}

- (void)updateNavigationItem:(BOOL)animated
{
    NSMutableArray *rightBarItems = [[NSMutableArray alloc] init];

    if (self.presentationStyle == MITNewsPresentationStyleList) {
        if ([self supportsPresentationStyle:MITNewsPresentationStyleGrid]) {
            UIBarButtonItem *gridItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(showStoriesAsGrid:)];
            [rightBarItems addObject:gridItem];
        }
    } else if (self.presentationStyle == MITNewsPresentationStyleGrid) {
        if ([self supportsPresentationStyle:MITNewsPresentationStyleList]) {
            UIImage *listImage = [UIImage imageNamed:@"map/item_list"];
            UIBarButtonItem *listItem = [[UIBarButtonItem alloc] initWithImage:listImage style:UIBarButtonItemStylePlain target:self action:@selector(showStoriesAsList:)];
            [rightBarItems addObject:listItem];
        }
    }
    
    if (self.searching) {
        UISearchBar *searchBar = [self.searchController returnSearchBar];
        
        UIView *barWrapper = [[UIView alloc]initWithFrame:searchBar.bounds];
        [barWrapper addSubview:searchBar];
        UIBarButtonItem *searchBarItem = [[UIBarButtonItem alloc] initWithCustomView:barWrapper];
        self.searchBar = searchBar;
        [rightBarItems addObject:searchBarItem];

    } else {
        UIBarButtonItem *searchItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonWasTriggered:)];
        [rightBarItems addObject:searchItem];
    }
    [self.navigationItem setRightBarButtonItems:rightBarItems animated:animated];
}

@end

@implementation MITNewsiPadViewController (NewsDataSource)
- (void)loadDataSources:(void (^)(NSError*))completion
{
    NSMutableArray *dataSources = [[NSMutableArray alloc] init];

    if (self.showsFeaturedStories) {
        MITNewsDataSource *featuredDataSource = [MITNewsStoriesDataSource featuredStoriesDataSource];
        featuredDataSource.maximumNumberOfItemsPerPage = 5;
        [dataSources addObject:featuredDataSource];
    }

    __weak MITNewsiPadViewController *weakSelf = self;
    [[MITNewsModelController sharedController] categories:^(NSArray *categories, NSError *error) {
        MITNewsiPadViewController *blockSelf = weakSelf;

        if (!blockSelf) {
            return;
        } else {
            NSMutableOrderedSet *categorySet = [[NSMutableOrderedSet alloc] init];

            [categories enumerateObjectsUsingBlock:^(MITNewsCategory *category, NSUInteger idx, BOOL *stop) {
                NSManagedObjectID *objectID = [category objectID];
                NSError *error = nil;
                NSManagedObject *object = [blockSelf.managedObjectContext existingObjectWithID:objectID error:&error];

                if (!object) {
                    DDLogWarn(@"failed to retreive object for ID %@: %@",object,error);
                } else {
                    [categorySet addObject:object];
                }
            }];

            [categories enumerateObjectsUsingBlock:^(MITNewsCategory *category, NSUInteger idx, BOOL *stop) {
                MITNewsDataSource *dataSource = [MITNewsStoriesDataSource dataSourceForCategory:category];
                [dataSources addObject:dataSource];
            }];

            blockSelf.categories = [categorySet array];
            blockSelf.dataSources = dataSources;
            [blockSelf refreshDataSources:completion];
        }
    }];
}

- (void)refreshDataSources:(void (^)(NSError*))completion
{
    __block dispatch_group_t refreshGroup = dispatch_group_create();
    __block NSError *updateError = nil;

    [self.dataSources enumerateObjectsUsingBlock:^(MITNewsDataSource *dataSource, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(refreshGroup);

        [dataSource refresh:^(NSError *error) {
            if (error) {
                DDLogWarn(@"failed to refresh data source %@",dataSource);

                if (!updateError) {
                    updateError = error;
                }
            } else {
                DDLogVerbose(@"refreshed data source %@",dataSource);
            }

            dispatch_group_leave(refreshGroup);
        }];
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        dispatch_group_wait(refreshGroup, DISPATCH_TIME_FOREVER);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(updateError);
        });

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (self.activeViewController == self.gridViewController) {
                [self.gridViewController.collectionView reloadData];
            } else if (self.activeViewController == self.listViewController) {
                [self.listViewController.tableView reloadData];
            }
        }];
    });
}

- (MITNewsDataSource*)dataSourceForCategoryInSection:(NSUInteger)section
{
    return self.dataSources[section];
}

- (BOOL)canLoadMoreItemsForCategoryInSection:(NSUInteger)section
{
    MITNewsDataSource *dataSource = [self dataSourceForCategoryInSection:index];
    return [dataSource hasNextPage];
}

- (BOOL)loadMoreItemsForCategoryInSection:(NSUInteger)section completion:(void(^)(NSError *error))block
{
    MITNewsDataSource *dataSource = [self dataSourceForCategoryInSection:index];
    return [dataSource nextPage:block];
}

- (void)reloadItems:(void(^)(NSError *error))block
{
    if (_dataSources) {
        [self refreshDataSources:block];
    } else {
        [self loadDataSources:block];
    }
}

#pragma mark UITableViewDataSource

- (NSUInteger)numberOfCategoriesInViewController:(UIViewController*)viewController
{
    return [self.dataSources count];
}

- (NSString*)viewController:(UIViewController*)viewController titleForCategoryInSection:(NSUInteger)section
{
    if (self.isSearching) {
        return nil;
    } else if (self.showsFeaturedStories && (section == 0)) {
        return @"Featured";
    } else {
        __block NSString *title = nil;
        --section;

        MITNewsCategory *category = self.categories[section];
        [category.managedObjectContext performBlockAndWait:^{
            title = category.name;
        }];

        return title;
    }
}

- (NSUInteger)viewController:(UIViewController*)viewController numberOfStoriesForCategoryInSection:(NSUInteger)section
{
    if (self.showsFeaturedStories && (section == 0)) {
        return 5;
    } else {
        MITNewsDataSource *dataSource = [self dataSourceForCategoryInSection:section];
        return MIN([dataSource.objects count],10);
    }
}

- (MITNewsStory*)viewController:(UIViewController*)viewController storyAtIndex:(NSUInteger)index forCategoryInSection:(NSUInteger)section
{
    MITNewsDataSource *dataSource = [self dataSourceForCategoryInSection:section];
    return dataSource.objects[index];
}

#pragma mark MITNewsStoryDetailPagingDelegate

- (MITNewsStory*)newsDetailController:(MITNewsStoryViewController*)storyDetailController storyAfterStory:(MITNewsStory*)story
{
#warning find better way to implement
    for (int i = 0 ; i < [self.stories count] ; i ++) {
        MITNewsStory *storyFromArray = [self.stories objectAtIndex:i];
        if ([story.identifier isEqualToString:storyFromArray.identifier]) {
            if ([self.stories count] > i + 1) {
                return [self.stories objectAtIndex:i + 1];
            }
        }
    };
    
    return nil;
}

- (MITNewsStory*)newsDetailController:(MITNewsStoryViewController*)storyDetailController storyBeforeStory:(MITNewsStory*)story
{
    return nil;
}

- (BOOL)newsDetailController:(MITNewsStoryViewController*)storyDetailController canPageToStory:(MITNewsStory*)story
{
    return nil;
}

- (void)newsDetailController:(MITNewsStoryViewController*)storyDetailController didPageToStory:(MITNewsStory*)story
{

}

@end
