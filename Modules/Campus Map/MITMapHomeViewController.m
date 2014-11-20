#import "MITMapHomeViewController.h"
#import "MITMapModelController.h"
#import "MITMapPlace.h"
#import "MITTiledMapView.h"
#import "MITMapPlaceAnnotationView.h"
#import "MITMapResultsListViewController.h"
#import "MITMapBrowseContainerViewController.h"
#import "CoreData+MITAdditions.h"
#import "UIKit+MITAdditions.h"
#import "MITMapPlaceDetailViewController.h"
#import "MITMapPlaceSelector.h"
#import "MITMapTypeAheadTableViewController.h"
#import "MITSlidingViewController.h"

static NSString * const kMITMapPlaceAnnotationViewIdentifier = @"MITMapPlaceAnnotationView";

typedef NS_ENUM(NSUInteger, MITMapSearchQueryType) {
    MITMapSearchQueryTypeText,
    MITMapSearchQueryTypePlace,
    MITMapSearchQueryTypeCategory
};

@interface MITMapHomeViewController () <UISearchBarDelegate, MKMapViewDelegate, MITTiledMapViewButtonDelegate, MITMapResultsListViewControllerDelegate, MITMapPlaceSelectionDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIBarButtonItem *bookmarksBarButton;
@property (nonatomic, strong) UIBarButtonItem *menuBarButton;
@property (nonatomic) BOOL searchBarShouldBeginEditing;
@property (nonatomic) MITMapSearchQueryType searchQueryType;
@property (nonatomic, strong) MITMapTypeAheadTableViewController *typeAheadViewController;
@property (nonatomic, strong) UIPopoverController *typeAheadPopoverController;
@property (nonatomic) BOOL isShowingIpadResultsList;
@property (nonatomic, strong) UIPopoverController *currentPlacePopoverController;
@property (nonatomic, strong) UIPopoverController *bookmarksPopoverController;

@property (weak, nonatomic) IBOutlet MITTiledMapView *tiledMapView;
@property (nonatomic, readonly) MKMapView *mapView;
@property (nonatomic) BOOL showFirstCalloutOnNextMapRegionChange;
@property (nonatomic) BOOL shouldRefreshAnnotationsOnNextMapRegionChange;

@property (nonatomic, copy) NSString *searchQuery;
@property (nonatomic, copy) NSArray *places;
@property (nonatomic, strong) MITMapCategory *category;

@end

@implementation MITMapHomeViewController

#pragma mark - Map View

- (MKMapView *)mapView
{
    return self.tiledMapView.mapView;
}

#pragma mark - Init

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _searchBarShouldBeginEditing = YES;
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupNavigationBar];
    [self setupMapView];
    [self setupTypeAheadTableView];
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        [self.navigationController setToolbarHidden:NO];
        [self.tiledMapView setButtonsHidden:YES animated:NO];
        
        UIBarButtonItem *listBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:MITImageBarButtonMenu] style:UIBarButtonItemStylePlain target:self action:@selector(ipadListButtonPressed)];
        UIBarButtonItem *currentLocationBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:MITImageBarButtonLocation] style:UIBarButtonItemStylePlain target:self action:@selector(ipadCurrentLocationButtonPressed)];
        UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        self.toolbarItems = @[listBarButton, flexibleSpace, currentLocationBarButton];
    } else {
        [self.navigationController setToolbarHidden:YES];
        [self.tiledMapView setButtonsHidden:NO animated:NO];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationItem setHidesBackButton:YES animated:NO];
    [self registerForKeyboardNotifications];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self unregisterForKeyboardNotifications];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.navigationItem setHidesBackButton:NO animated:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Setup

- (void)setupNavigationBar
{
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(-10, 0, 340, 44)];
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.placeholder = @"Search MIT Campus";
    // Insert the correct clear button image and uncomment the next line when ready
//    [searchBar setImage:[UIImage imageNamed:@""] forSearchBarIcon:UISearchBarIconClear state:UIControlStateNormal];
    
    UIView *searchBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    searchBarView.autoresizingMask = 0;
    self.searchBar.delegate = self;
    [searchBarView addSubview:self.searchBar];
    self.navigationItem.titleView = searchBarView;
    
    self.bookmarksBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(bookmarksButtonPressed)];
    [self.navigationItem setRightBarButtonItem:self.bookmarksBarButton];
    [self.navigationItem setLeftBarButtonItem:[MIT_MobileAppDelegate applicationDelegate].rootViewController.leftBarButtonItem];
}

- (void)setupMapView
{
    self.tiledMapView.buttonDelegate = self;
    
    [self.tiledMapView setMapDelegate:self];
    self.mapView.showsUserLocation = YES;
    
    // This sets the color of the current location pin, which is otherwise inherited from the main window's MIT tint color...
    self.mapView.tintColor = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];
    [self setupMapBoundingBoxAnimated:NO];
}

- (void)setupTypeAheadTableView
{
    self.typeAheadViewController = [[MITMapTypeAheadTableViewController alloc] initWithStyle:UITableViewStylePlain];
    self.typeAheadViewController.delegate = self;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        self.typeAheadPopoverController = [[UIPopoverController alloc] initWithContentViewController:self.typeAheadViewController];
        self.typeAheadViewController.showsTitleHeader = YES;
    } else {
        [self addChildViewController:self.typeAheadViewController];
        self.typeAheadViewController.view.alpha = 0;
        self.typeAheadViewController.view.frame = CGRectZero;
        [self.view addSubview:self.typeAheadViewController.view];
        [self.typeAheadViewController didMoveToParentViewController:self];
    }
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)unregisterForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

#pragma mark - Private Methods

- (void)closePopoversAnimated:(BOOL)animated
{
    if (self.typeAheadPopoverController.isPopoverVisible) {
        [self.typeAheadPopoverController dismissPopoverAnimated:animated];
    }
    
    if (self.bookmarksPopoverController.isPopoverVisible) {
        [self.bookmarksPopoverController dismissPopoverAnimated:animated];
    }
    
    if (self.currentPlacePopoverController.isPopoverVisible) {
        [self.currentPlacePopoverController dismissPopoverAnimated:animated];
    }
}

#pragma mark - Button Actions

- (void)bookmarksButtonPressed
{
    MITMapBrowseContainerViewController *browseContainerViewController = [[MITMapBrowseContainerViewController alloc] initWithNibName:nil bundle:nil];
    [browseContainerViewController setDelegate:self];
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:browseContainerViewController];
    navigationController.navigationBarHidden = YES;
    navigationController.toolbarHidden = NO;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        self.bookmarksPopoverController = [[UIPopoverController alloc] initWithContentViewController:navigationController];
        [self.bookmarksPopoverController presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    } else {
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }
}

- (void)ipadListButtonPressed
{
    if (self.isShowingIpadResultsList) {
        [self closeIpadResultsList];
    } else {
        [self openIpadResultsList];
    }
}

- (void)closeIpadResultsList
{
    if (self.isShowingIpadResultsList) {
        MITMapResultsListViewController *resultsVC = [self resultsListViewController];
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            resultsVC.view.frame = CGRectMake(-320, resultsVC.view.frame.origin.y, resultsVC.view.frame.size.width, resultsVC.view.frame.size.height);
        } completion:nil];
        self.isShowingIpadResultsList = NO;
    }
}

- (void)openIpadResultsList
{
    if (!self.isShowingIpadResultsList) {
        MITMapResultsListViewController *resultsVC = [self resultsListViewController];
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            resultsVC.view.frame = CGRectMake(0, resultsVC.view.frame.origin.y, resultsVC.view.frame.size.width, resultsVC.view.frame.size.height);
        } completion:nil];
        self.isShowingIpadResultsList = YES;
    }
}

- (void)ipadCurrentLocationButtonPressed
{
    [self.tiledMapView centerMapOnUserLocation];
}

#pragma mark - Search Bar

- (void)closeSearchBar
{
    [self.navigationItem setLeftBarButtonItem:self.menuBarButton animated:YES];
    [self.navigationItem setRightBarButtonItem:self.bookmarksBarButton animated:YES];
    [self.searchBar setShowsCancelButton:NO animated:YES];
    
}

- (void)setSearchBarTextColor:(UIColor *)color
{
    // A public API would be preferable, but UIAppearance doesn't update unless you remove the view from superview and re-add, which messes with the display
    UITextField *searchBarTextField = [self.searchBar textField];
    searchBarTextField.textColor = color;
}

- (void)setSearchQueryType:(MITMapSearchQueryType)searchQueryType
{
    UIColor *searchBarTextColor = (searchQueryType == MITMapSearchQueryTypeText) ? [UIColor blackColor] : [UIColor mit_tintColor];
    [self setSearchBarTextColor:searchBarTextColor];
    _searchQueryType = searchQueryType;
}

#pragma mark - Map View

- (void)setupMapBoundingBoxAnimated:(BOOL)animated
{
    [self.view layoutIfNeeded]; // ensure that map has autoresized before setting region
    
    if ([self.places count] > 0) {
        MKMapRect zoomRect = MKMapRectNull;
        for (id <MKAnnotation> annotation in self.places)
        {
            MKMapPoint annotationPoint = MKMapPointForCoordinate(annotation.coordinate);
            MKMapRect pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0.1, 0.1);
            zoomRect = MKMapRectUnion(zoomRect, pointRect);
        }
        double inset = -zoomRect.size.width * 0.1;
        [self.mapView setVisibleMapRect:MKMapRectInset(zoomRect, inset, inset) animated:YES];
    } else {
        [self.mapView setRegion:kMITShuttleDefaultMapRegion animated:animated];
    }
}

#pragma mark - Places

- (void)setPlaces:(NSArray *)places
{
    [self setPlaces:places animated:NO];
}

- (void)setPlaces:(NSArray *)places animated:(BOOL)animated
{
    _places = places;
    [[self resultsListViewController] setPlaces:places];
    self.shouldRefreshAnnotationsOnNextMapRegionChange = YES;
    self.showFirstCalloutOnNextMapRegionChange = YES;
    [self setupMapBoundingBoxAnimated:animated];
}

- (void)clearPlacesAnimated:(BOOL)animated
{
    self.category = nil;
    self.searchQuery = nil;
    self.searchQueryType = MITMapSearchQueryTypeText;
    [self setPlaces:nil animated:animated];
}

- (void)refreshPlaceAnnotations
{
    [self removeAllPlaceAnnotations];
    [self.mapView addAnnotations:self.places];
}

- (void)removeAllPlaceAnnotations
{
    NSMutableArray *annotationsToRemove = [NSMutableArray array];
    for (id <MKAnnotation> annotation in self.mapView.annotations) {
        if ([annotation isKindOfClass:[MITMapPlace class]]) {
            [annotationsToRemove addObject:annotation];
        }
    }
    [self.mapView removeAnnotations:annotationsToRemove];
}

#pragma mark - Search Results

- (void)keyboardWillShow:(NSNotification *)notification
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height + 20; // +20 for the status bar
        CGRect endFrame = [[notification.userInfo valueForKeyPath:UIKeyboardFrameEndUserInfoKey] CGRectValue];
        
        // Apple doesn't give the keyboard frame in the current view's coordinate system, it gives it in the window one, so width/height can be reversed when in landscape mode.
        endFrame = [self.view convertRect:endFrame fromView:nil];
        
        CGFloat tableViewHeight = self.view.frame.size.height - endFrame.size.height - navBarHeight;
        self.typeAheadViewController.view.frame = CGRectMake(0, navBarHeight, self.view.frame.size.width, tableViewHeight);
        [UIView animateWithDuration:0.5 animations:^{
            self.typeAheadViewController.view.alpha = 1;
        }];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        [UIView animateWithDuration:0.5 animations:^{
            self.typeAheadViewController.view.alpha = 0;
        } completion:^(BOOL finished) {
            // We need to set the frame to nothing, as interface orientation changes can accidentally leave this table in view
            if (finished) {
                self.typeAheadViewController.view.frame = CGRectZero;
            }
        }];
    }
}

- (void)updateSearchResultsForSearchString:(NSString *)searchString
{
    [self.typeAheadViewController updateResultsWithSearchTerm:searchString];
}

- (void)performSearchWithQuery:(NSString *)query
{
    self.searchQuery = query;
    [[MITMapModelController sharedController] addRecentSearch:query];
    [[MITMapModelController sharedController] searchMapWithQuery:query
                                                          loaded:^(NSArray *objects, NSError *error) {
                                                              if (objects) {
                                                                  [self setPlaces:objects animated:YES];
                                                              }
                                                          }];
}

- (void)setPlacesWithQuery:(NSString *)query
{
    [self performSearchWithQuery:query];
    self.category = nil;
    self.searchBar.text = query;
    self.searchQueryType = MITMapSearchQueryTypeText;
}

- (void)setPlacesWithPlace:(MITMapPlace *)place
{
    [[MITMapModelController sharedController] addRecentSearch:place];
    self.searchQuery = nil;
    self.category = nil;
    [self setPlaces:@[place] animated:YES];
    self.searchBar.text = place.name;
    self.searchQueryType = MITMapSearchQueryTypePlace;
}

- (void)setPlacesWithCategory:(MITMapCategory *)category
{
    [[MITMapModelController sharedController] addRecentSearch:category];
    self.category = category;
    self.searchQuery = nil;
    NSArray *places = category.allPlaces;
    [self setPlaces:places animated:YES];
    self.searchBar.text = category.name;
    self.searchQueryType = MITMapSearchQueryTypeCategory;
}

- (void)pushDetailViewControllerForPlace:(MITMapPlace *)place
{
    MITMapPlaceDetailViewController *detailVC = [[MITMapPlaceDetailViewController alloc] initWithNibName:nil bundle:nil];
    detailVC.place = place;
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (void)showCalloutForPlace:(MITMapPlace *)place
{
    if ([self.places containsObject:place]) {
        [self.mapView selectAnnotation:place animated:YES];
    }
}

- (void)showTypeAheadPopover
{
    [self.typeAheadPopoverController presentPopoverFromRect:CGRectMake(self.searchBar.bounds.size.width / 2, self.searchBar.bounds.size.height, 1, 1) inView:self.searchBar permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
}

- (MITMapResultsListViewController *)resultsListViewController
{
    static MITMapResultsListViewController *resultsListViewController;
    if (!resultsListViewController) {
        resultsListViewController = [[MITMapResultsListViewController alloc] initWithPlaces:self.places];
        resultsListViewController.delegate = self;
        
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            resultsListViewController.hideDetailButton = YES;
            resultsListViewController.view.frame = CGRectMake(-320, 64, 320, self.view.bounds.size.height - 64 - 44);
            resultsListViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
            self.isShowingIpadResultsList = NO;
            
            [self addChildViewController:resultsListViewController];
            [resultsListViewController beginAppearanceTransition:YES animated:NO];
            [self.view addSubview:resultsListViewController.view];
            
            [resultsListViewController endAppearanceTransition];
            [resultsListViewController didMoveToParentViewController:self];
        }
    }
    
    switch (self.searchQueryType) {
        case MITMapSearchQueryTypeText: {
            [resultsListViewController setTitleWithSearchQuery:self.searchQuery];
            break;
        }
        case MITMapSearchQueryTypePlace: {
            MITMapPlace *place = [self.places firstObject];
            [resultsListViewController setTitle:place.name];
            break;
        }
        case MITMapSearchQueryTypeCategory: {
            [resultsListViewController setTitle:self.category.name];
            break;
        }
        default:
            break;
    }
    
    return resultsListViewController;
}

#pragma mark - UISearchBarDelegate Methods

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        [self showTypeAheadPopover];
    } else {
        [self.navigationItem setLeftBarButtonItem:nil animated:YES];
        [self.navigationItem setRightBarButtonItem:nil animated:YES];
        [self.searchBar setShowsCancelButton:YES animated:YES];

    }
    
    [self updateSearchResultsForSearchString:self.searchQuery];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    [self closeSearchBar];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    [self.typeAheadPopoverController dismissPopoverAnimated:YES];
    self.searchQueryType = MITMapSearchQueryTypeText;
    [self performSearchWithQuery:searchBar.text];
}

- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if (self.searchQueryType != MITMapSearchQueryTypeText) {
        searchBar.text = text;
        self.searchQueryType = MITMapSearchQueryTypeText;
    }
    return YES;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self updateSearchResultsForSearchString:searchText];
    
    if (searchBar.isFirstResponder) {
        if (!self.typeAheadPopoverController.popoverVisible) {
            [self showTypeAheadPopover];
        }
    } else {
        self.searchBarShouldBeginEditing = NO;
        [self clearPlacesAnimated:YES];
    }
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    BOOL shouldBeginEditing = self.searchBarShouldBeginEditing;
    self.searchBarShouldBeginEditing = YES;
    return shouldBeginEditing;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    if ([searchBar.text length] == 0) {
        [self clearPlacesAnimated:YES];
    }
}

#pragma mark - MITTiledMapViewButtonDelegate

- (void)mitTiledMapViewRightButtonPressed:(MITTiledMapView *)mitTiledMapView
{
    UINavigationController *resultsListNavigationController = [[UINavigationController alloc] initWithRootViewController:[self resultsListViewController]];
    [self presentViewController:resultsListNavigationController animated:YES completion:nil];
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MITMapPlace class]]) {
        MITMapPlaceAnnotationView *annotationView = (MITMapPlaceAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:kMITMapPlaceAnnotationViewIdentifier];
        if (!annotationView) {
            annotationView = [[MITMapPlaceAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:kMITMapPlaceAnnotationViewIdentifier];
        }
        NSInteger placeIndex = [self.places indexOfObject:annotation];
        [annotationView setNumber:(placeIndex + 1)];
        return annotationView;
    }
    return nil;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKTileOverlay class]]) {
        return [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];
    }
    return nil;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad && [view isKindOfClass:[MITMapPlaceAnnotationView class]]) {
        MITMapPlace *place = view.annotation;
        MITMapPlaceDetailViewController *detailVC = [[MITMapPlaceDetailViewController alloc] initWithNibName:nil bundle:nil];
        detailVC.place = place;
        self.currentPlacePopoverController = [[UIPopoverController alloc] initWithContentViewController:detailVC];
        UIView *annotationView = [self.mapView viewForAnnotation:place];
        
        CGFloat tableHeight = 0;
        for (NSInteger section = 0; section < [detailVC numberOfSectionsInTableView:detailVC.tableView]; section++) {
            for (NSInteger row = 0; row < [detailVC tableView:detailVC.tableView numberOfRowsInSection:section]; row++) {
                tableHeight += [detailVC tableView:detailVC.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
            }
        }
        
        CGFloat navbarHeight = 44;
        CGFloat statusBarHeight = 20;
        CGFloat toolbarHeight = 44;
        CGFloat padding = 30;
        CGFloat maxPopoverHeight = self.view.bounds.size.height - navbarHeight - statusBarHeight - toolbarHeight - (2 * padding);
        
        if (tableHeight > maxPopoverHeight) {
            tableHeight = maxPopoverHeight;
        }
        
        self.currentPlacePopoverController.passthroughViews = @[self.navigationController.toolbar];
        [self.currentPlacePopoverController setPopoverContentSize:CGSizeMake(320, tableHeight) animated:NO];
        [self.currentPlacePopoverController presentPopoverFromRect:annotationView.bounds inView:annotationView permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [self addCalloutTapGestureRecognizerToAnnotationView:view];
    }
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        [self removeCalloutTapGestureFromAnnotationView:view];
    }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    if ([view isKindOfClass:[MITMapPlaceAnnotationView class]]) {
        MITMapPlace *place = view.annotation;
        [self pushDetailViewControllerForPlace:place];
    }
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    if (self.shouldRefreshAnnotationsOnNextMapRegionChange) {
        [self refreshPlaceAnnotations];
        self.shouldRefreshAnnotationsOnNextMapRegionChange = NO;
    }
    
    if (self.showFirstCalloutOnNextMapRegionChange) {
        if (self.places.count > 0) {
            [self showCalloutForPlace:[self.places firstObject]];
        }
        
        self.showFirstCalloutOnNextMapRegionChange = NO;
    }
}

#pragma mark - Callout Tap Gesture Recognizer

- (void)addCalloutTapGestureRecognizerToAnnotationView:(MKAnnotationView *)view
{
    // Make the entire callout tappable, not just the disclosure button
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(mapViewDidSelectAnnotationCallout:)];
    [view addGestureRecognizer:tapGestureRecognizer];
}

- (void)removeCalloutTapGestureFromAnnotationView:(MKAnnotationView *)view
{
    if ([view.gestureRecognizers count] > 0) {
        UITapGestureRecognizer *tapGestureRecognizer = nil;
        for (UIGestureRecognizer *gestureRecognizer in view.gestureRecognizers) {
            if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
                tapGestureRecognizer = (UITapGestureRecognizer *)gestureRecognizer;
                break;
            }
        }
        if (tapGestureRecognizer) {
            [view removeGestureRecognizer:tapGestureRecognizer];
        }
    }
}

- (void)mapViewDidSelectAnnotationCallout:(UITapGestureRecognizer *)recognizer
{
    MKAnnotationView *annotationView = (MKAnnotationView *)recognizer.view;
    if ([annotationView isKindOfClass:[MITMapPlaceAnnotationView class]]) {
        MITMapPlace *place = (MITMapPlace *)annotationView.annotation;
        [self pushDetailViewControllerForPlace:place];
    }
}

#pragma mark - MITMapResultsListViewControllerDelegate

- (void)resultsListViewController:(MITMapResultsListViewController *)viewController didSelectPlace:(MITMapPlace *)place
{
    [self showCalloutForPlace:place];
}

#pragma mark - MITMapPlaceSelectionDelegate

- (void)placeSelectionViewController:(UIViewController <MITMapPlaceSelector >*)viewController didSelectPlace:(MITMapPlace *)place
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self setPlacesWithPlace:place];
        }];
    } else {
        [self.searchBar resignFirstResponder];
        [self closePopoversAnimated:YES];
        [self setPlacesWithPlace:place];
    }
}

- (void)placeSelectionViewController:(UIViewController<MITMapPlaceSelector> *)viewController didSelectCategory:(MITMapCategory *)category
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self setPlacesWithCategory:category];
        }];
    } else {
        [self.searchBar resignFirstResponder];
        [self closePopoversAnimated:YES];
        [self setPlacesWithCategory:category];
    }
}

- (void)placeSelectionViewController:(UIViewController<MITMapPlaceSelector> *)viewController didSelectQuery:(NSString *)query
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:^{
            [self setPlacesWithQuery:query];
        }];
    } else {
        [self.searchBar resignFirstResponder];
        [self closePopoversAnimated:YES];
        [self setPlacesWithQuery:query];
    }
}

@end