//
//  TagExplorerTVC.m
//  SPoT
//
//  Created by Corneliu on 4/12/13.
//  Copyright (c) 2013 Corneliu. All rights reserved.
//

#import "TagExplorerTVC.h"
#import "FlickrFetcher.h"
#import "NetworkActivityIndicator.h"

#define TAGS_TO_EXCLUDE @[@"cs193pspot",@"portrait", @"landscape"]

@interface TagExplorerTVC ()<UISplitViewControllerDelegate>

@property (strong, nonatomic) NSArray*           tags;          //NSStrings
@property (strong, nonatomic) NSSet*             tagsToExclude; //NSStrings
@property (strong, nonatomic) NSDictionary*      photoHierarchyByTag;//NSDictionary with NSArrays of NSDictionaries as values (sets of photos), and NSString (tag) as key
@property (strong, nonatomic) NSArray*           flickrPhotos;

@end

@implementation TagExplorerTVC

// for IPad 
- (void)awakeFromNib
{
    self.splitViewController.delegate = self;
}

- (BOOL)splitViewController:(UISplitViewController *)svc
   shouldHideViewController:(UIViewController *)vc
              inOrientation:(UIInterfaceOrientation)orientation
{
    return NO;
}

- (NSSet*) tagsToExclude
{
    return [[NSSet alloc] initWithArray:TAGS_TO_EXCLUDE];
}



- (NSArray*) tags
{
    if(_tags){
        return _tags;
    }
    else{
        if(self.flickrPhotos){
            NSMutableSet* allTagsSet = [[FlickrFetcher getTagsForPhotos:self.flickrPhotos] mutableCopy]; //custom method
            [allTagsSet minusSet:self.tagsToExclude];
            _tags = [[allTagsSet allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2){
                      return [obj1 compare:obj2 options:NSCaseInsensitiveSearch];}
                    ];
        }
    }
    return _tags;
}


- (void) updatedPhotoHierarchyByTag
{
    self.photoHierarchyByTag = [FlickrFetcher groupPhotos:self.flickrPhotos
                                                   byTags:self.tags]; //custom method
}


- (void)setFlickrPhotos:(NSArray *)flickrPhotos
{
    _flickrPhotos = flickrPhotos;
    [self updatedPhotoHierarchyByTag];
    [self.tableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self getStandfordPhotos];
    [self.refreshControl addTarget:self action:@selector(getStandfordPhotos) forControlEvents:UIControlEventValueChanged];
}

- (void) getStandfordPhotos
{
    [self.refreshControl beginRefreshing];
    dispatch_queue_t imageFetcher = dispatch_queue_create(" flicker fetcher", NULL);
    dispatch_async(imageFetcher, ^{
        [NetworkActivityIndicator push];
        NSArray* flickrStanfordPhotos = [FlickrFetcher stanfordPhotos];
        [NetworkActivityIndicator pop];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.flickrPhotos = flickrStanfordPhotos;
            [self.refreshControl endRefreshing];
        });
    });
}

#pragma mark - Segue related things

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        if (indexPath) {
            if ([segue.identifier isEqualToString:@"Show Photos With Tag"]) {
                if ([segue.destinationViewController respondsToSelector:@selector(setFlickrPhotos:)]) {
                    NSString *tag = [self titleForRow:indexPath.row];
                    NSArray* sortedPhotos;
                    sortedPhotos = [self.photoHierarchyByTag[tag]
                                    sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2){
                                            return [[obj1[FLICKR_PHOTO_TITLE] description]
                                                    compare:[obj2[FLICKR_PHOTO_TITLE] description]
                                                    options:NSCaseInsensitiveSearch
                                                   ];}
                                   ];
                    [segue.destinationViewController performSelector:@selector(setFlickrPhotos:)
                                                          withObject:sortedPhotos];
                    [segue.destinationViewController setTitle:tag];
                }
            }
        }
    }
}

#pragma mark - Table view data source


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.tags count];
}

- (NSString *)titleForRow:(NSUInteger)row
{
    return [self.tags objectAtIndex:row];
}

- (NSString *)subtitleForRow:(NSUInteger)row
{
    NSString* rowTag = [self.tags objectAtIndex:row];
    NSUInteger numOfPhotosWithTag = [[self.photoHierarchyByTag objectForKey:rowTag] count];
    return [NSString stringWithFormat:@"%d", numOfPhotosWithTag];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Tag Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    cell.textLabel.text       = [self titleForRow:indexPath.row];
    cell.detailTextLabel.text = [self subtitleForRow:indexPath.row];
    
    return cell;
}


@end
