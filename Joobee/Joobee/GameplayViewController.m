//
//  ViewController.m
//  Joobee
//
//  Created by Jordan on 9/22/14.
//  Copyright (c) 2014 Byjor. All rights reserved.
//

#import "GameplayViewController.h"
#import <Firebase/Firebase.h>

@interface GameplayViewController ()

@property (strong, nonatomic) IBOutlet UILabel *timeRemaining;
@property (strong, nonatomic) IBOutlet UILabel *blueScore;
@property (strong, nonatomic) IBOutlet UILabel *redScore;
@property (strong, nonatomic) IBOutlet UISegmentedControl *teamSelection;

@property (strong, nonatomic) IBOutlet UIProgressView *beaconOneStatus;
@property (strong, nonatomic) IBOutlet UILabel *beaconOnePossession;

@property (strong, nonatomic) IBOutlet UIProgressView *beaconTwoStatus;
@property (strong, nonatomic) IBOutlet UILabel *beaconTwoPossession;

@property (strong, nonatomic) IBOutlet UIProgressView *beaconThreeStatus;
@property (strong, nonatomic) IBOutlet UILabel *beaconThreePossession;

@end

static NSString* const kBaseURL = @"https://blistering-heat-4085.firebaseio.com/";
static NSString* const kGameplay = @"GameSession/Gameplay/";


@implementation GameplayViewController {
    NSDictionary *thisPlayer;
    NSString *playerName;
    NSString *myTeam;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    playerName = [NSString stringWithFormat:@"player%i",arc4random_uniform(500)];
    thisPlayer = @{ playerName : playerName, };
    myTeam = @"Team1";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Temp UI Buttons

- (IBAction)attachFlag1:(id)sender {
    [self addSelfToFlag:1];
}

- (IBAction)detachFlag1:(id)sender {
    [self removeSelfFromFlag:1];
}

#pragma mark - Flags
// methods used by all players
-(void)addSelfToFlag:(int)flagNumber {
    // make call to FB and add self to Flag#, NearbyPlayers, [myTeam]
    NSString *url = [NSString stringWithFormat:@"%@%@Flags/Flag%i/NearbyPlayers/%@",kBaseURL,kGameplay,flagNumber,myTeam];
    Firebase* nearFlag = [[Firebase alloc] initWithUrl:url];
    [nearFlag updateChildValues:thisPlayer];
}

-(void)removeSelfFromFlag:(int)flagNumber {
    NSString *url = [NSString stringWithFormat:@"%@%@Flags/Flag%i/NearbyPlayers/%@",kBaseURL,kGameplay,flagNumber,myTeam];
    Firebase* nearFlag = [[Firebase alloc] initWithUrl:url];
    Firebase* leaveFlag = [nearFlag childByAppendingPath:[NSString stringWithFormat:@"/%@",playerName]];
    [leaveFlag removeValue];
}

#pragma mark - Game Logic
// methods only run by the game host
// at time interval X
// for each flag
// get number of NearbyPlayers from each team
// get net difference (Team1 - Team2)
// positive number means Team1 gains control, negative Team2, 0 no change
// add net diff to flagStatus
// for each flag
// if flagStatus is >25, Team1 controls the flag and gains points
// "" < -25, Team2 ""
// else no one controls it and no points are awarded

@end
