#import "HomePageController.h"
#import "WeiboCell.h"
#import "WBCellBuilder.h"
#import "WBRequestManager.h"

@interface HomePageController()<UITableViewDataSource,UITableViewDelegate>
{
    NSMutableArray* _cellBuilders;
    WBRequestManager* _manager;
    UITableView* _table;
}
@end


@implementation HomePageController

- (instancetype)init
{
    if (self = [super init]) {
        _cellBuilders = [NSMutableArray new];
        _manager = [WBRequestManager new];
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self initTableView];
    [self setUpRefreshControlAndLaunchFirstRefresh];
}

- (void)initTableView
{
    CGRect PageFrame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame));
    _table = [[UITableView alloc]initWithFrame:PageFrame style:UITableViewStylePlain];
    _table.delegate = self;
    _table.dataSource = self;
    [self.view addSubview:_table];
}

- (void)setUpRefreshControlAndLaunchFirstRefresh
{
    UIRefreshControl* updateControl = [[UIRefreshControl alloc]init];
    [updateControl addTarget:self action:@selector(updateStatusList:) forControlEvents:UIControlEventValueChanged];
    [_table addSubview:updateControl];
    [self updateStatusList:updateControl];
}

- (void)updateStatusList:(UIRefreshControl*)control
{
    __block  NSUInteger insertIndex = 0;
    static NSString* sinceID = @"0";
    
    [control beginRefreshing];
    [_manager homeStatusesWithSinceID:sinceID maxID:@"0" didReiceverStatus:^(WBStatus* status){
        WBCellBuilder* cellcontroller = [[WBCellBuilder alloc]initWithStatus:status];
        [_cellBuilders insertObject:cellcontroller atIndex:insertIndex];
        insertIndex++;;
    } finish:^{
        [_table reloadData];
        [control endRefreshing];
        WBCellBuilder* cellcontroller = [_cellBuilders firstObject];
        sinceID = cellcontroller.status.statusID;
    } fail:^(NSError* error){
        NSLog(@"some err by  ,\n%s,\n%@",__func__,error);
        [control endRefreshing];
    }];
}

- (void)loadOldStatusIntoList:(UIRefreshControl*)control
{
    __block  NSUInteger insertIndex = 0;
    static NSString* maxID = @"0";
    [_manager homeStatusesWithSinceID:@"0" maxID:maxID didReiceverStatus:^(WBStatus* status){
        WBCellBuilder* cellcontroller = [[WBCellBuilder alloc]initWithStatus:status];
        [_cellBuilders insertObject:cellcontroller atIndex:insertIndex];
        insertIndex++;
    } finish:^{
        [_table reloadData];
        [control endRefreshing];
        WBCellBuilder* cellcontroller = [_cellBuilders lastObject];
        maxID = cellcontroller.status.statusID;
    } fail:^(NSError* error){
        NSLog(@"some err by  ,\n%s,\n%@",__func__,error);
        [control endRefreshing];
    }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString* iden = [NSString stringWithFormat:@"iden %lu",([indexPath row] % 6)];
    WeiboCell* cell = [tableView dequeueReusableCellWithIdentifier:iden];
    if (!cell) {
        cell = [[WeiboCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:iden];
    }
    
    WBCellBuilder* cellcontroller = [_cellBuilders objectAtIndex:[indexPath row]];
    [cellcontroller constructCell:cell];

    return cell;
}



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_cellBuilders count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    WBCellBuilder* cellcontroller = [_cellBuilders objectAtIndex:[indexPath row]];
    return cellcontroller.heightOfCell;
}

@end
