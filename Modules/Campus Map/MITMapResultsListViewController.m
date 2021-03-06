#import "MITMapResultsListViewController.h"
#import "MITMapCategory.h"
#import "MITMapPlace.h"
#import "MITMapPlaceCell.h"
#import "MITMapPlaceDetailViewController.h"

static NSString * const kMITMapResultsListDefaultTitle = @"Results";

static NSString * const kMITMapNumberedResultCellIdentifier = @"MITMapNumberedResultCell";

@interface MITMapResultsListViewController ()

@property (nonatomic, strong) UIView *noResultsView;

@end

@implementation MITMapResultsListViewController

#pragma mark - Init

- (instancetype)initWithPlaces:(NSArray *)places
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _places = places;
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupTableView];
    [self setupDoneBarButtonItem];
    [self setupBackBarButtonItem];
    [self setupNoResultsView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setNoResultsViewHidden:([self.places count] > 0)];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Rotation

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    [self.tableView reloadData];
}

#pragma mark - Setup

- (void)setupTableView
{
    UINib *numberedResultCellNib = [UINib nibWithNibName:NSStringFromClass([MITMapPlaceCell class]) bundle:nil];
    [self.tableView registerNib:numberedResultCellNib forCellReuseIdentifier:kMITMapNumberedResultCellIdentifier];
}

- (void)setupDoneBarButtonItem
{
    UIBarButtonItem *doneButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneBarButtonItemTapped:)];
    self.navigationItem.rightBarButtonItem = doneButtonItem;
}

- (void)setupBackBarButtonItem
{
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:nil action:nil];
}

#pragma mark - No Results View

- (void)setupNoResultsView
{
    UILabel *noResultsLabel = [[UILabel alloc] init];
    noResultsLabel.text = @"No Results";
    noResultsLabel.font = [UIFont systemFontOfSize:24.0];
    noResultsLabel.textColor = [UIColor grayColor];
    noResultsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIView *noResultsView = [[UIView alloc] initWithFrame:self.tableView.bounds];
    [noResultsView addSubview:noResultsLabel];
    [noResultsView addConstraints:@[[NSLayoutConstraint constraintWithItem:noResultsLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:noResultsView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0],
                                    [NSLayoutConstraint constraintWithItem:noResultsLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:noResultsView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0]]];
    self.noResultsView = noResultsView;
}

- (void)setNoResultsViewHidden:(BOOL)hidden
{
    self.tableView.separatorStyle = hidden ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundView = hidden ? nil : self.noResultsView;
}

#pragma mark - Public Methods

- (void)setPlaces:(NSArray *)places
{
    _places = places;
    [self.tableView reloadData];
}

#pragma mark - Button Actions

- (void)doneBarButtonItemTapped:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Title

- (void)setTitleWithSearchQuery:(NSString *)query
{
    self.navigationItem.title = query ? [NSString stringWithFormat:@"\"%@\"", query] : kMITMapResultsListDefaultTitle;
}

#pragma mark - Table View Helpers

- (void)configureCell:(MITMapPlaceCell *)cell forIndexPath:(NSIndexPath *)indexPath
{
    NSInteger index = indexPath.row;
    [cell setPlace:self.places[index] order:(index + 1)];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.places count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MITMapPlaceCell *cell = [tableView dequeueReusableCellWithIdentifier:kMITMapNumberedResultCellIdentifier forIndexPath:indexPath];
    [self configureCell:cell forIndexPath:indexPath];
    cell.accessoryType = self.hideDetailButton ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDetailButton;
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return kMapPlaceCellEstimatedHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [MITMapPlaceCell heightForPlace:self.places[indexPath.row] order:(indexPath.row + 1)
                            tableViewWidth:self.tableView.frame.size.width
                             accessoryType:UITableViewCellAccessoryDetailButton];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        if ([self.delegate respondsToSelector:@selector(resultsListViewController:didSelectPlace:)]) {
            MITMapPlace *place = self.places[indexPath.row];
            [self.delegate resultsListViewController:self didSelectPlace:place];
        }
    } else {
        [self dismissViewControllerAnimated:YES completion:^{
            if ([self.delegate respondsToSelector:@selector(resultsListViewController:didSelectPlace:)]) {
                MITMapPlace *place = self.places[indexPath.row];
                [self.delegate resultsListViewController:self didSelectPlace:place];
            }
        }];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    MITMapPlace *place = self.places[indexPath.row];
    MITMapPlaceDetailViewController *detailVC = [[MITMapPlaceDetailViewController alloc] initWithNibName:nil bundle:nil];
    detailVC.place = place;
    [self.navigationController pushViewController:detailVC animated:YES];
}

@end
