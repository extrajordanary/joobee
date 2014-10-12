//
//  ViewController.m
//  Joobee
//
//  Created by Jordan on 9/22/14.
//  Copyright (c) 2014 Byjor. All rights reserved.
//

#import "GameplayViewController.h"
#import <Firebase/Firebase.h>
#import "AppDelegate.h"

@interface GameplayViewController ()

@property (strong, nonatomic) IBOutlet UILabel *timeRemaining;
@property (strong, nonatomic) IBOutlet UILabel *teamTwoScore;
@property (strong, nonatomic) IBOutlet UILabel *teamOneScore;
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
static NSString* const kGameState = @"https://blistering-heat-4085.firebaseio.com/GameSession/Gameplay/"; // = gameState
static NSString* const kFlags = @"https://blistering-heat-4085.firebaseio.com/GameSession/Gameplay/Flags/";


@implementation GameplayViewController {
    NSDictionary *gameState;
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
    
    [self subscribeToGameUpdates];
    [self setUpEstimoteManager];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.teamSelection.selectedSegmentIndex) {
        myTeam = @"Team2";
    } else myTeam = @"Team1";
    NSLog(myTeam);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)subscribeToGameUpdates {
    Firebase *gameRef = [[Firebase alloc] initWithUrl:kGameState];
    [gameRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        gameState = snapshot.value;
//        NSLog(@"Game State: %@", gameState);
    } withCancelBlock:^(NSError *error) {
        NSLog(@"%@", error.description);
    }];
}
#pragma mark - UI Buttons

- (IBAction)attachFlag1:(id)sender {
    [self addSelfToFlag:1];
}

- (IBAction)detachFlag1:(id)sender {
    [self removeSelfFromFlag:1];
}

- (IBAction)updateGameState:(id)sender {
    [self updateGameState];
}

- (IBAction)selectTeam:(id)sender {
    if (self.teamSelection.selectedSegmentIndex) {
        myTeam = @"Team2";
    } else myTeam = @"Team1";
    NSLog(myTeam);
}

#pragma mark - UI
-(void)updateFlagProgressBar:(int)flagNumber withValue:(int)value{
    float flagControlUIStatus = ((float)value/2 + 50)/100;
    
    if (flagNumber == 1) {
        self.beaconOneStatus.progress = flagControlUIStatus;
    } else if (flagNumber == 2) {
        self.beaconTwoStatus.progress = flagControlUIStatus;
    } else self.beaconThreeStatus.progress = flagControlUIStatus;
}

-(void)updateFlagControlText:(int)flagNumber withTeam:(NSString*)controllingTeam {
    if (flagNumber == 1) {
        self.beaconOnePossession.text = controllingTeam;
    } else if (flagNumber == 2) {
        self.beaconTwoPossession.text = controllingTeam;
    } else self.beaconThreePossession.text = controllingTeam;
}

-(void)updateScoreForTeamOne:(NSString*)team1 teamTwo:(NSString*)team2 {
    self.teamOneScore.text = [NSString stringWithFormat:@"T1: %@",team1];
    self.teamTwoScore.text = [NSString stringWithFormat:@"T2: %@",team2];
}

#pragma mark - Flag Proximity
// methods used by all players
-(void)addSelfToFlag:(int)flagNumber {
    // make call to FB and add self to Flag#, NearbyPlayers, [myTeam]
    NSString *url = [NSString stringWithFormat:@"%@Flag%i/NearbyPlayers/%@",kFlags,flagNumber,myTeam];
    Firebase* nearFlag = [[Firebase alloc] initWithUrl:url];
    [nearFlag updateChildValues:thisPlayer];
}

-(void)removeSelfFromFlag:(int)flagNumber {
    NSString *url = [NSString stringWithFormat:@"%@Flag%i/NearbyPlayers/%@",kFlags,flagNumber,myTeam];
    Firebase* nearFlag = [[Firebase alloc] initWithUrl:url];
    Firebase* leaveFlag = [nearFlag childByAppendingPath:[NSString stringWithFormat:@"/%@",playerName]];
    [leaveFlag removeValue];
}

#pragma mark - Game Logic
// methods only run by the game host
-(void)updateGameState {
    for (int i = 1; i < 4; i++) {
        [self updateFlagStatus:i];
        [self updateFlagControl:i];
    }
    [self updateTeamPoints];
}

-(void)updateFlagStatus:(int)flagNumber {
    // get number of NearbyPlayers from each team
    // get net difference (Team1 - Team2)
    // positive number means Team1 gains control, negative Team2, 0 no change
    // add net diff to flagStatus
    NSString *theFlag = [NSString stringWithFormat:@"Flag%i",flagNumber];
    int team1Count = 0;
    int team2Count = 0;
    for (int i = 1; i < 3; i++) {
        NSString *theTeam = [NSString stringWithFormat:@"Team%i",i];
        NSDictionary *nearbyPlayers = gameState[@"Flags"][theFlag][@"NearbyPlayers"][theTeam];
        int count = (int)[[nearbyPlayers allKeys] count];
        if (i == 1) {
            team1Count = count;
        } else {
            team2Count = count;
        }
    }
    int netDiff = team1Count - team2Count;
    int currentControlStatusValue = [[gameState[@"Flags"][theFlag] objectForKey:@"ControlStatus"] intValue];
    currentControlStatusValue = MIN(MAX(-100, currentControlStatusValue + netDiff),100);
    NSNumber *newControlStatusValue = @(currentControlStatusValue);
    NSDictionary *newControlStatus = @{ @"ControlStatus" : newControlStatusValue };
    
    NSString *url = [NSString stringWithFormat:@"%@Flag%i",kFlags,flagNumber];
    Firebase *updateFlag = [[Firebase alloc] initWithUrl:url];
    [updateFlag updateChildValues:newControlStatus];

    [self updateFlagProgressBar:flagNumber withValue:currentControlStatusValue];
}

-(void)updateFlagControl:(int)flagNumber {
    // if flagStatus is >25, Team1 controls the flag
    // "" < -25, Team2 ""
    // else no one controls it
    NSString *theFlag = [NSString stringWithFormat:@"Flag%i",flagNumber];
    int currentControlStatusValue = [[gameState[@"Flags"][theFlag] objectForKey:@"ControlStatus"] intValue];
    NSString *controllingTeam;
    if (currentControlStatusValue > 25) {
        controllingTeam = @"Team1";
    } else if (currentControlStatusValue < -25) {
        controllingTeam = @"Team2";
    } else controllingTeam = @"-";
    
    NSDictionary *newControllingTeam = @{ @"ControllingTeam" : controllingTeam };
    NSString *url = [NSString stringWithFormat:@"%@Flag%i",kFlags,flagNumber];
    Firebase *updateFlag = [[Firebase alloc] initWithUrl:url];
    [updateFlag updateChildValues:newControllingTeam];

    [self updateFlagControlText:flagNumber withTeam:controllingTeam];
}

-(void)updateTeamPoints {
    // for each flag controlled, teams gain X points
    int team1Score = [[gameState[@"RoundScore"] objectForKey:@"Team1"] intValue];
    int team2Score = [[gameState[@"RoundScore"] objectForKey:@"Team2"] intValue];
    
    for (int i = 1; i < 4; i ++) {
        NSString *theFlag = [NSString stringWithFormat:@"Flag%i",i];
        NSString *controllingTeam = [gameState[@"Flags"][theFlag] objectForKey:@"ControllingTeam"];
        if ([controllingTeam isEqualToString:@"Team1"]) {
            team1Score++;
        } else if ([controllingTeam isEqualToString:@"Team2"]) {
            team2Score++;
        }
    }
    NSString *score1 = [NSString stringWithFormat:@"%i",team1Score];
    NSString *score2 = [NSString stringWithFormat:@"%i",team2Score];
    NSDictionary *newTeamScores = @{ @"RoundScore" : @{
                                        @"Team1" : score1,
                                        @"Team2" : score2
                                        }
                                     };
    NSString *url = kGameState;
    Firebase *updateScores = [[Firebase alloc] initWithUrl:url];
    [updateScores updateChildValues:newTeamScores];
    
    [self updateScoreForTeamOne:score1 teamTwo:score2];
}

#pragma mark - Estimote SDK and Delegate
-(void)setUpEstimoteManager {
    self.beaconManager = [[ESTBeaconManager alloc] init];
    self.beaconManager.delegate = self;
    [self.beaconManager requestAlwaysAuthorization];
    [self.beaconManager startRangingBeaconsInRegion:nil];
}

-(void)beaconManager:(ESTBeaconManager *)manager
rangingBeaconsDidFailForRegion:(ESTBeaconRegion *)region
           withError:(NSError *)error{
    
}

- (void)beaconManager:(ESTBeaconManager *)manager
didFailDiscoveryInRegion:(ESTBeaconRegion *)region {
    
}

-(void)beaconManager:(ESTBeaconManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(ESTBeaconRegion *)region {
    BOOL nearFlag1 = NO;
    BOOL nearFlag2 = NO;
    BOOL nearFlag3 = NO;
    
        for (ESTBeacon * beacon in beacons) {
            if (beacon.distance.floatValue>0.0f && beacon.distance.floatValue<0.5f) {
                NSInteger major = beacon.major.integerValue;
                switch (major) {
                    case 13372:
                        nearFlag1 = YES;
                        break;
                    case 15271:
                        nearFlag2 = YES;
                        break;
                    case 20062:
                        nearFlag3 = YES;
                        break;
                    default:
                        break;
                }
            }
        }
    NSLog(nearFlag1 ? @"1 Yes" : @"1 No");
    NSLog(nearFlag2 ? @"2 Yes" : @"2 No");
    NSLog(nearFlag2 ? @"3 Yes" : @"3 No");
    
    if (nearFlag1) {
        [self addSelfToFlag:1];
    } else [self removeSelfFromFlag:1];
    if (nearFlag2) {
        [self addSelfToFlag:2];
    } else [self removeSelfFromFlag:2];
    if (nearFlag3) {
        [self addSelfToFlag:3];
    } else [self removeSelfFromFlag:3];
}

@end
