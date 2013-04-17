//
//  PlayerController.m
//  ePlayer
//
//  Created by Eric Huss on 4/12/13.
//  Copyright (c) 2013 Eric Huss. All rights reserved.
//

#import "EPPlayerController.h"
#import "EPPlayerCellView.h"

static NSTimeInterval scrubberUpdateTime = 0.300;

@interface EPPlayerController ()
{
    Folder *_queueFolder;
}
@end

@implementation EPPlayerController

+ (EPPlayerController *)sharedPlayer
{
    static EPPlayerController *sharedSingleton;
    
    if (!sharedSingleton) {
        // A bit messy, but avoids creating another storyboard object.
        UIStoryboard *storyboard = [UIApplication sharedApplication].delegate.window.rootViewController.storyboard;
        sharedSingleton = [storyboard instantiateViewControllerWithIdentifier:@"PlayerScene"];
    }
    
    return sharedSingleton;
}

- (Folder *)queueFolder
{
    if (_queueFolder == nil) {
        NSFetchRequest *request = [self.managedObjectModel fetchRequestTemplateForName:@"QueueFolder"];
        NSError *error;
        NSArray *results = [self.managedObjectContext executeFetchRequest:request error:&error];
        if (results==nil || results.count==0) {
            NSLog(@"Failed to fetch queue folder: %@", error);
            return nil;
        }
        _queueFolder = results[0];
    }
    return _queueFolder;
}

- (void)loadCurrentQueue
{
    BOOL loadQueue = YES;
    if (self.player.nowPlayingItem == nil) {
        // Load queue from disk.
        NSLog(@"now playing is nil");
    } else {
        // Check if now playing is in db queue.
        BOOL found = NO;
        NSNumber *persistentID = [self.player.nowPlayingItem valueForProperty:MPMediaItemPropertyPersistentID];
        NSLog(@"Check if %@ %@ is in queue.", persistentID, [self.player.nowPlayingItem valueForProperty:MPMediaItemPropertyTitle]);
        for (Song *song in self.queueFolder.entries) {
            NSLog(@"Check against %@ %@", song.UPID, song.name);
            if ([song.UPID isEqualToNumber:persistentID]) {
                found = YES;
                break;
            }
        }
        if (!found) {
            NSLog(@"Now playing %@ is not in queue.", [self.player.nowPlayingItem valueForProperty:MPMediaItemPropertyTitle]);
            loadQueue = NO;
        }
    }
    if (loadQueue) {
        // Assume the queue is the same.
        if (self.queueFolder.sortedEntries.count) {
            // Populate queueItems from the queue folder.
            NSArray *items = [self.queueFolder.sortedEntries mapWithBlock:^id(Song * song) {
                MPMediaQuery *query = [[MPMediaQuery alloc] init];
                MPMediaPropertyPredicate *pred = [MPMediaPropertyPredicate
                                                  predicateWithValue:song.persistentID
                                                  forProperty:MPMediaItemPropertyPersistentID];
                [query addFilterPredicate:pred];
                NSArray *result = query.items;
                if (result.count) {
                    return result[0];
                } else {
                    NSLog(@"Failed to fetch MPMediaItem for persistent ID song %@.", song.persistentID);
                    return nil;
                }
            }];
            self.queueItems = [MPMediaItemCollection collectionWithItems:items];
        }
    }    
}

- (BOOL)isDisplayed
{
    return self.parentViewController != nil;
}

- (void)awakeFromNib
{
    self.player = [MPMusicPlayerController iPodMusicPlayer];
    [self registerNotifications];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"View will appear.");
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopTimer];
}

//- (void)viewWillAppear:(BOOL)animated
//{
//    [super viewWillAppear:animated];
//    [self.tableView reloadData];
//}
//
//- (void)didReceiveMemoryWarning
//{
//    [super didReceiveMemoryWarning];
//    // Dispose of any resources that can be recreated.
//}

/****************************************************************************/
/* Table Data Source                                                        */
/****************************************************************************/
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if (self.queueItems) {
        return self.queueItems.count;
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"PlayerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell==nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        EPPlayerCellView *cview = [[EPPlayerCellView alloc] initWithFrame:cell.contentView.frame];
        [cell.contentView addSubview:cview];
    }
    EPPlayerCellView *cview = cell.contentView.subviews[0];
    MPMediaItem *item = self.queueItems.items[indexPath.row];
    cview.queueNumLabel.text = [NSString stringWithFormat:@"%i.", indexPath.row+1];
    cview.trackNameLabel.text = [item valueForProperty:MPMediaItemPropertyTitle];
    int duration = (int)[[item valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
    cview.trackTimeLabel.text = [NSString stringWithFormat:@"%i:%02i",
                                 duration/60, duration%60];
    return cell;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!(indexPath.row%2)) {
        cell.backgroundColor = [UIColor colorWithWhite:0.16f alpha:1.0f];
    } else {
        cell.backgroundColor = [UIColor colorWithWhite:0.10f alpha:1.0f];
    }
}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 }
 else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */

- (void)tableView:(UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)fromIndexPath
      toIndexPath:(NSIndexPath *)toIndexPath
{
//    MPMediaItem *item = [self.queueItems objectAtIndex:fromIndexPath.row];
//    [self.queueItems removeObjectAtIndex:fromIndexPath.row];
//    [self.queueItems insertObject:item atIndex:toIndexPath.row];
}


/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

/****************************************************************************/
/* Table Delegate                                                           */
/****************************************************************************/
#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"Selected cell.");
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    
}

/****************************************************************************/
/* Button Actions                                                           */
/****************************************************************************/
- (void)tappedPrev:(id)sender
{
    [self.player skipToPreviousItem];
}

- (IBAction)tappedPlay:(id)sender
{
    if (self.player.playbackState == MPMusicPlaybackStatePlaying) {
        [self pause];
    } else {
        // Not currently playing.
        if (self.queueItems) {
            [self play];
        }
    }
}

- (IBAction)tappedNext:(id)sender
{
    [self.player skipToNextItem];
}

- (IBAction)tappedSave:(id)sender
{
    
}

- (IBAction)scrubberDidUpdate:(id)sender
{
    // XXX: Track change while holding scrubber?  Stop/pause/interrupt?
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    // Don't update too frequently.
    if ((now-self.lastScrubberUpdate) > scrubberUpdateTime) {
        MPMediaItem *item = self.player.nowPlayingItem;
        // Compute the playback time for this thumb position.
        NSTimeInterval duration = (int)[[item valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
        NSTimeInterval newPlaybackTime = duration*self.scrubber.value;
        // Only alter it if the change is >= 1 second.
        if ((int)newPlaybackTime != self.lastScrubberPlayTime) {
            self.lastScrubberPlayTime = (int)newPlaybackTime;
            self.lastScrubberUpdate = now;
            self.player.currentPlaybackTime = duration*self.scrubber.value;
            NSLog(@"updated to %f", self.player.currentPlaybackTime);
            [self updateTimeLabels];
        }
    }
    NSLog(@"scrubber update %f %f", self.scrubber.scrubbingSpeed,
          self.scrubber.value);
}

- (IBAction)scrubberTouchDown:(id)sender
{
    self.scrubberUpdateDisabled = YES;
    // So first update will update player.
    self.lastScrubberUpdate = 0;//[NSDate timeIntervalSinceReferenceDate];
    self.lastScrubberPlayTime = (int)self.player.currentPlaybackTime;
}
- (IBAction)scrubberTouchUp:(id)sender
{
    self.scrubberUpdateDisabled = NO;
}


/****************************************************************************/
/* Player/Queue Methods                                                     */
/****************************************************************************/
- (void)play
{
    NSLog(@"Playing...");
    [self.player play];
}

- (void)pause
{
    [self.player pause];
}

- (void)stop
{
    NSLog(@"Stop action.");
    [self.player stop];
}

- (void)clearQueue
{
    NSLog(@"Clearing queue and stopping.");
    [self.player stop];
    // Ugh, initWithItems raises an exception with an empty array.
    // Fake it out.
    MPMediaQuery *q = [[MPMediaQuery alloc] init];
    [q addFilterPredicate:[MPMediaPropertyPredicate
                            predicateWithValue:@"__EP_INVALID_NAME__"
                            forProperty:MPMediaItemPropertyTitle]];
    self.queueItems = nil;
    [self.player setQueueWithQuery:q];
    self.player.nowPlayingItem = nil;
    [self.tableView reloadData];
    // Clear the db copy of the queue.
    [self.queueFolder removeEntries:self.queueFolder.entries];
    NSError *error;
    if (![self.managedObjectContext save:&error]) {
        NSLog(@"Failed to save: %@", error);
    }
}

- (void)addQueueItems:(NSArray *)items
{
    NSLog(@"Adding to queue: %@", items);
    NSArray *newItems;
    if (self.queueItems) {
        newItems = [self.queueItems.items arrayByAddingObjectsFromArray:items];
    } else {
        newItems = items;
    }
    self.queueItems = [[MPMediaItemCollection alloc] initWithItems:newItems];
    [self.player setQueueWithItemCollection:self.queueItems];
    [self.tableView reloadData];
    // Save the db copy.
    for (MPMediaItem *item in items) {
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Song"
                                                  inManagedObjectContext:self.managedObjectContext];
        request.entity = entity;
        NSNumber *itemID = [item valueForProperty:MPMediaItemPropertyPersistentID];
        request.predicate = [NSPredicate predicateWithFormat:@"persistentID==%@", itemID];
        NSError *error;
        NSArray *results = [self.managedObjectContext executeFetchRequest:request error:&error];
        if (results == nil || results.count==0) {
            NSLog(@"Failed to query for entries: %@", error);
        } else {
            Song *song = results[0];
            NSLog(@"adding %@", song);
            [self.queueFolder addEntriesObject:song];
        }
    }
    NSError *error;
    if (![self.managedObjectContext save:&error]) {
        NSLog(@"Failed to save: %@", error);
    }
    
}

/****************************************************************************/
/* Media Player Notifications                                               */
/****************************************************************************/

- (void)registerNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(nowPlayingItemChanged:)
                               name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification
                             object:self.player];
    [notificationCenter addObserver:self
                           selector:@selector(playbackStateChanged:)
                               name:MPMusicPlayerControllerPlaybackStateDidChangeNotification
                             object:self.player];
    [notificationCenter addObserver:self
                           selector:@selector(volumeChanged:)
                               name:MPMusicPlayerControllerVolumeDidChangeNotification
                             object:self.player];
    [notificationCenter addObserver:self
                           selector:@selector(libraryChanged:)
                               name:MPMediaLibraryDidChangeNotification
                             object:self.player];
    [self.player beginGeneratingPlaybackNotifications];
}

- (void)nowPlayingItemChanged:(id)notification
{
    MPMediaItem *item = self.player.nowPlayingItem;
    NSLog(@"now playing changed %@.", item);
//    @property (weak, nonatomic) IBOutlet UIImageView *artImageView;
    self.artistNameLabel.text = [item valueForProperty:MPMediaItemPropertyArtist];
    self.albumNameLabel.text = [item valueForProperty:MPMediaItemPropertyAlbumTitle];
    self.trackNameLabel.text = [item valueForProperty:MPMediaItemPropertyTitle];
    NSNumber *year = [item valueForProperty:@"year"];
    if (year == nil || [year intValue]==0) {
        self.releasedDateLabel.text = nil;
    } else {
        self.releasedDateLabel.text = [NSString stringWithFormat:@"Released %i", [year integerValue]];
    }
    // scrubbing forward/backward?
    if (self.player.playbackState == MPMusicPlaybackStatePlaying) {
        [self startTimer];
    }
    [self updateScrubber];
}

- (void)updateTimeLabels
{
    MPMediaItem *item = self.player.nowPlayingItem;
    if (item) {
        self.currentTimeLabel.text = [NSString stringWithFormat:@"%i:%02i",
                                      ((int)self.player.currentPlaybackTime)/60,
                                      ((int)self.player.currentPlaybackTime)%60];
        
        NSTimeInterval duration = (int)[[item valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
        int timeLeft = duration - self.player.currentPlaybackTime;
        
        self.timeLeftLabel.text = [NSString stringWithFormat:@"-%i:%02i",
                                   timeLeft/60,
                                   timeLeft%60];
    } else {
        self.currentTimeLabel.text = @"0:00";
        self.timeLeftLabel.text = @"0:00";
    }

}

- (void)updateScrubber
{
    [self updateTimeLabels];
    MPMediaItem *item = self.player.nowPlayingItem;
    if (item) {
        NSTimeInterval duration = (int)[[item valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
        [self.scrubber setValue:self.player.currentPlaybackTime/duration animated:YES];
    } else {
        [self.scrubber setValue:0 animated:YES];
    }
}

- (void)startTimer
{
    if (self.timer == nil) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(timerFired:)
                                                    userInfo:nil
                                                     repeats:YES];
        self.scrubberUpdateDisabled = NO;
    }
}

- (void)stopTimer
{
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)timerFired:(NSTimer *)timer
{
    NSLog(@"timer fired %@", self.isDisplayed ? @"YES" : @"NO");
    if (self.isDisplayed) {
        if (self.scrubberUpdateDisabled) {
            [self updateTimeLabels];
        } else {
            [self updateScrubber];
        }
    }
}

- (void)playbackStateChanged:(id)notification
{
    switch (self.player.playbackState) {
        case MPMusicPlaybackStateStopped:
            NSLog(@"Notification: playback stopped");
            [self.playButton setImage:[UIImage imageNamed:@"queue-play"] forState:UIControlStateNormal];
            // Ensure the music player will play the queue from the start.
            [self.player stop];
            [self stopTimer];
            break;
        case MPMusicPlaybackStatePlaying:
            NSLog(@"Notification: playback playing");
            [self.playButton setImage:[UIImage imageNamed:@"queue-pause"] forState:UIControlStateNormal];
            [self startTimer];
            break;
        case MPMusicPlaybackStatePaused:
            NSLog(@"Notification: playback paused");
            [self.playButton setImage:[UIImage imageNamed:@"queue-play"] forState:UIControlStateNormal];
            [self stopTimer];
            break;
        case MPMusicPlaybackStateInterrupted:
            NSLog(@"Notification: playback interrupted");
            [self stopTimer];
            break;
        case MPMusicPlaybackStateSeekingForward:
            NSLog(@"Notification: playback seek forward");
            [self updateScrubber];
            break;
        case MPMusicPlaybackStateSeekingBackward:
            NSLog(@"Notification: playback seek backward");
            [self updateScrubber];
            break;
    }
}

- (void)volumeChanged:(id)notification
{
    // XXX: media player volume vs system volume?
    NSLog(@"volume changed");
}

- (void)libraryChanged:(id)notification
{
    NSLog(@"Library changed.");
}

@end