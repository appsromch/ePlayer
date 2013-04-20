//
//  EPLibTableController.m
//  ePlayer
//
//  Created by Eric Huss on 4/19/13.
//  Copyright (c) 2013 Eric Huss. All rights reserved.
//

#import "EPLibTableController.h"

@implementation EPLibTableController

- (NSArray *)supportedSortOrders
{
    return @[@(EPSortOrderAlpha),
             @(EPSortOrderPlayDate),
             @(EPSortOrderReleaseDate)];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setSOButtonToSortOrder];
}

/*****************************************************************************/
/* The "Sort Order" Button                                                   */
/*****************************************************************************/

- (void)touchSortOrder:(id)sender
{
    [self setSOButtonToSortOrder];
    [super touchSortOrder:sender];
}

- (void)setSOButtonToSortOrder
{
    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithTitle:@"Sort Order"
                                     style:UIBarButtonItemStyleBordered
                                    target:self action:@selector(touchedNavSortOrder:)];
}

- (void)setSOButtonToDone
{
    self.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                  target:self
                                                  action:@selector(touchedSODone:)];
}

- (void)touchedNavSortOrder:(UIBarButtonItem *)sender
{
    // Add row at the top to set sort order.
    self.hasSortCell = YES;
    [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
    [self setSOButtonToDone];
}

- (void)touchedSODone:(id)sender
{
    self.hasSortCell = NO;
    [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
    [self setSOButtonToSortOrder];
}

@end