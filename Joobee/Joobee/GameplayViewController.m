//
//  ViewController.m
//  Joobee
//
//  Created by Jordan on 9/22/14.
//  Copyright (c) 2014 Byjor. All rights reserved.
//

/*
TODO: 
 - app run in background
 - push notifications of events: claimed flag, flag lost, other team stole flag, game start, game end
 - game over
 - game about to start
 - show number of players at each flag
 DONE- pre-game choose team, then disabled when game starts
 - convert seconds to minutes and seconds
*/
#import "GameplayViewController.h"
#import <Firebase/Firebase.h>
#import "AppDelegate.h"

@interface GameplayViewController ()

@property (strong, nonatomic) IBOutlet UILabel *timeRemaining;
@property (strong, nonatomic) IBOutlet UILabel *teamTwoScore;
@property (strong, nonatomic) IBOutlet UILabel *teamOneScore;
@property (strong, nonatomic) IBOutlet UISegmentedControl *teamSelection;
@property (strong, nonatomic) IBOutlet UILabel *hostLabel;

@property (strong, nonatomic) IBOutlet UIProgressView *beaconOneStatus;
@property (strong, nonatomic) IBOutlet UILabel *beaconOnePossession;
@property (strong, nonatomic) IBOutlet UIView *beaconOneNearby;

@property (strong, nonatomic) IBOutlet UIProgressView *beaconTwoStatus;
@property (strong, nonatomic) IBOutlet UILabel *beaconTwoPossession;
@property (strong, nonatomic) IBOutlet UIView *beaconTwoNearby;

@property (strong, nonatomic) IBOutlet UIProgressView *beaconThreeStatus;
@property (strong, nonatomic) IBOutlet UILabel *beaconThreePossession;
@property (strong, nonatomic) IBOutlet UIView *beaconThreeNearby;

@end

static NSString* const kBaseURL = @"https://blistering-heat-4085.firebaseio.com/";
static NSString* const kGameplay = @"GameSession/Gameplay/";
static NSString* const kGameSession = @"https://blistering-heat-4085.firebaseio.com/GameSession/";
static NSString* const kGameState = @"https://blistering-heat-4085.firebaseio.com/GameSession/Gameplay/";
static NSString* const kFlags = @"https://blistering-heat-4085.firebaseio.com/GameSession/Gameplay/Flags/";


@implementation GameplayViewController {
    NSDictionary *gameState;
    NSDictionary *thisPlayer;
    NSString *playerName;
    NSString *myTeam;
    int secondsRemaining;
    NSTimer *updateTimer;
//    BOOL canChooseTeam;
    BOOL gameActive;
    BOOL gameOver;
    BOOL isHost;
    int uiUpdate;
    
    UIColor *nearFlag;
    UIColor *notNearFlag;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    int randomNum = arc4random_uniform(500);
    playerName = [NSString stringWithFormat:@"player%i",randomNum];
    thisPlayer = @{ playerName : playerName, };
    
    if (randomNum % 2) {
        myTeam = @"Team2";
        [self.teamSelection setSelectedSegmentIndex: (NSInteger)1];
    } else {
        myTeam = @"Team1";
    }
    gameActive = NO;
    gameOver = NO;
    isHost = NO;
    uiUpdate = 0;
    self.hostLabel.hidden = YES;
    
    nearFlag = [UIColor colorWithRed:(252.0/255.0) green:(243.0/255.0) blue:(171.0/255.0) alpha:1.0];
    notNearFlag = [UIColor colorWithRed:246.0/255.0 green:246.0/255.0 blue:246.0/255.0 alpha:1.0];
    
    [self subscribeToGameUpdates];
    [self setUpEstimoteManager];
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateGameState) userInfo:nil repeats:YES];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
//    if (self.teamSelection.selectedSegmentIndex) {
//        myTeam = @"Team2";
//    } else myTeam = @"Team1";
}

-(void)subscribeToGameUpdates {
    Firebase *gameRef = [[Firebase alloc] initWithUrl:kGameState];
    [gameRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        gameState = snapshot.value;
        
        [self updateUI];
        
    } withCancelBlock:^(NSError *error) {
        NSLog(@"%@", error.description);
    }];
}
#pragma mark - UI Buttons

- (IBAction)resetSettings:(id)sender { // temp
    [self resetFirebaseSettings];
}

- (IBAction)resetGameplay:(id)sender {
    [self resetFirebaseGameplay];
    
    // make self the host
    NSString *url = kGameState;
    Firebase *updateHost = [[Firebase alloc] initWithUrl:url];
    NSDictionary *newHost = @{ @"GameHost" : playerName };
    [updateHost updateChildValues:newHost];
    isHost = YES;
    self.hostLabel.hidden = NO;
}

- (IBAction)selectTeam:(id)sender {
    if (self.teamSelection.selectedSegmentIndex) {
        [self removeSelfFromFlag:1];
        [self removeSelfFromFlag:2];
        [self removeSelfFromFlag:3];
        
        myTeam = @"Team2";
    } else {
        [self removeSelfFromFlag:1];
        [self removeSelfFromFlag:2];
        [self removeSelfFromFlag:3];
        
        myTeam = @"Team1";
    }
}
- (IBAction)playPause:(id)sender {
    if (isHost) {
        if (gameActive) {
            gameActive = NO;
        } else gameActive = YES;
        
        // set FB value
        NSString *url = kGameState;
        Firebase* nearFlagUpdate = [[Firebase alloc] initWithUrl:url];
        NSString *active = gameActive ? @"YES" : @"NO";
        [nearFlagUpdate updateChildValues: @{ @"GameActive" : active }];
    }
}

#pragma mark - UI
-(void)updateUI {
    // everyone updates their UI
    [self updateFlagProgressBars];
    [self updateFlagControlTexts];
    [self updateTeamScores];
    [self updateTimeRemaining];
    uiUpdate ++;
    NSLog(@"UI update %i",uiUpdate);
}

-(void)updateFlagProgressBars {
    int statusValue1 = [[gameState[@"Flags"][@"Flag1"] objectForKey:@"ControlStatus"] intValue];
    int statusValue2 = [[gameState[@"Flags"][@"Flag2"] objectForKey:@"ControlStatus"] intValue];
    int statusValue3 = [[gameState[@"Flags"][@"Flag3"] objectForKey:@"ControlStatus"] intValue];
    float flag1UIStatus = ((float)statusValue1/2 + 50)/100;
    float flag2UIStatus = ((float)statusValue2/2 + 50)/100;
    float flag3UIStatus = ((float)statusValue3/2 + 50)/100;
    self.beaconOneStatus.progress = flag1UIStatus;
    self.beaconTwoStatus.progress = flag2UIStatus;
    self.beaconThreeStatus.progress = flag3UIStatus;
}

-(void)updateFlagControlTexts {
    self.beaconOnePossession.text = [gameState[@"Flags"][@"Flag1"] objectForKey:@"ControllingTeam"];
    self.beaconTwoPossession.text = [gameState[@"Flags"][@"Flag2"] objectForKey:@"ControllingTeam"];
    self.beaconThreePossession.text = [gameState[@"Flags"][@"Flag3"] objectForKey:@"ControllingTeam"];
}

-(void)updateTeamScores {
    int team1Score = [[gameState[@"RoundScore"] objectForKey:@"Team1"] intValue];
    int team2Score = [[gameState[@"RoundScore"] objectForKey:@"Team2"] intValue];
    NSString *score1 = [NSString stringWithFormat:@"%i",team1Score];
    NSString *score2 = [NSString stringWithFormat:@"%i",team2Score];
    self.teamOneScore.text = score1;
    self.teamTwoScore.text = score2;
}

-(void)updateTimeRemaining {
    gameOver = [[gameState objectForKey:@"GameOver"] isEqualToString:@"YES"];
    if (gameOver) {
        gameActive = NO;
        
        self.timeRemaining.text = @"GAME OVER";
    } else {
        gameActive = [[gameState objectForKey:@"GameActive"] isEqualToString:@"YES"];
        if (gameActive) {
            // can not switch teams -- not the best place for this... but meh
            self.teamSelection.userInteractionEnabled = NO;
            [self.teamSelection setEnabled:NO];
            
            
            secondsRemaining = [[gameState objectForKey:@"TimeRemaining"] intValue];
            int minutes = secondsRemaining/60;
            int seconds = secondsRemaining - (minutes*60);
            
            if (seconds < 10) {
                self.timeRemaining.text = [NSString stringWithFormat:@"%i:0%i",minutes,seconds];
            } else {
                self.timeRemaining.text = [NSString stringWithFormat:@"%i:%i",minutes,seconds];
            }
        } else {
            // can switch teams?
            self.teamSelection.userInteractionEnabled = YES;
            [self.teamSelection setEnabled:YES];
            self.timeRemaining.text = @"PAUSED";
        }
    }
}

#pragma mark - Flag Proximity
// methods used by all players
-(void)addSelfToFlag:(int)flagNumber {
    // make call to FB and add self to Flag#, NearbyPlayers, [myTeam]
    if (gameActive) {
        NSString *url = [NSString stringWithFormat:@"%@Flag%i/NearbyPlayers/%@",kFlags,flagNumber,myTeam];
        Firebase* nearFlagUpdate = [[Firebase alloc] initWithUrl:url];
        [nearFlagUpdate updateChildValues:thisPlayer];
        
        if (flagNumber == 1) {
            [self.beaconOneNearby setBackgroundColor:nearFlag];
        } else if (flagNumber == 2) {
            [self.beaconTwoNearby setBackgroundColor:nearFlag];
        } else {
            [self.beaconThreeNearby setBackgroundColor:nearFlag];
        }
    }
}

-(void)removeSelfFromFlag:(int)flagNumber {
    if (gameActive) {
        NSString *url = [NSString stringWithFormat:@"%@Flag%i/NearbyPlayers/%@",kFlags,flagNumber,myTeam];
        Firebase* nearFlagUpdate = [[Firebase alloc] initWithUrl:url];
        Firebase* leaveFlag = [nearFlagUpdate childByAppendingPath:[NSString stringWithFormat:@"/%@",playerName]];
        [leaveFlag removeValue];
        
        if (flagNumber == 1) {
            self.beaconOneNearby.backgroundColor = notNearFlag;
        } else if (flagNumber == 2) {
            self.beaconTwoNearby.backgroundColor = notNearFlag;
        } else {
            self.beaconThreeNearby.backgroundColor = notNearFlag;
        }
    }
}

#pragma mark - Game Logic
// methods only run by the game host
-(void)setGameHost {
    // set who the game host is
    if ([[gameState objectForKey:@"GameHost"] isEqualToString:@"-"]) {
        NSString *url = kGameState;
        Firebase *updateHost = [[Firebase alloc] initWithUrl:url];
        NSDictionary *newHost = @{ @"GameHost" : playerName };
        [updateHost updateChildValues:newHost];
        isHost = YES;
        self.hostLabel.hidden = NO;
    }
    if ([[gameState objectForKey:@"GameHost"] isEqualToString:playerName]) {
        isHost = YES;
        self.hostLabel.hidden = NO;
    } else {
        isHost = NO;
        self.hostLabel.hidden = YES;
    }
}

-(void)updateGameState {
//    [self setGameHost];
    if (gameActive) {
        // only one person updates calculated values
        if (isHost) {
            for (int i = 1; i < 4; i++) {
                [self updateFlagStatus:i];
                [self updateFlagControl:i];
            }
            [self updateTeamPoints];
            [self updateSecondsRemaining];
            
            // clear all players from flags after they've been counted
            [self resetNearbyPlayers];
        }
        if (secondsRemaining < 1) {
            gameOver = YES;
            
            // set FB value
            NSString *url = kGameState;
            Firebase *gameOverUpdate = [[Firebase alloc] initWithUrl:url];
            [gameOverUpdate updateChildValues: @{ @"GameOver" : @"YES" }];
            [gameOverUpdate updateChildValues: @{ @"GameActive" : @"NO" }];
        }
    }
//    if (gameOver) {
//        gameActive = NO;
//        
//        self.timeRemaining.text = @"GAME OVER";
//    }
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
}

-(void)updateFlagControl:(int)flagNumber {
    // if flagStatus is >25, Team1 controls the flag
    // "" < -25, Team2 ""
    // else no one controls it
    NSString *theFlag = [NSString stringWithFormat:@"Flag%i",flagNumber];
    int currentControlStatusValue = [[gameState[@"Flags"][theFlag] objectForKey:@"ControlStatus"] intValue];
    NSString *controllingTeam;
    if (currentControlStatusValue >= 25) {
        controllingTeam = @"Team1";
    } else if (currentControlStatusValue <= -25) {
        controllingTeam = @"Team2";
    } else controllingTeam = @"-";
    
    NSDictionary *newControllingTeam = @{ @"ControllingTeam" : controllingTeam };
    NSString *url = [NSString stringWithFormat:@"%@Flag%i",kFlags,flagNumber];
    Firebase *updateFlag = [[Firebase alloc] initWithUrl:url];
    [updateFlag updateChildValues:newControllingTeam];
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
}

-(void)updateSecondsRemaining {
    secondsRemaining = [[gameState objectForKey:@"TimeRemaining"] intValue];
    secondsRemaining--;
    NSString *newTime = [NSString stringWithFormat:@"%i",secondsRemaining];
    
    NSString *url = kGameState;
    Firebase *updateTime = [[Firebase alloc] initWithUrl:url];
    [updateTime updateChildValues: @{ @"TimeRemaining" : newTime } ];
}

-(void)resetNearbyPlayers {
    NSDictionary *clearNearby = @{ @"NearbyPlayers" : @{
                                                     @"Team1" : @{
                                                             @"player" : @"player"
                                                             },
                                                     @"Team2" : @{
                                                             @"player" : @"player"
                                                             }
                                                     }
                                   };
    for (int i = 1; i < 4; i++) {
        NSString *url = [NSString stringWithFormat:@"%@Flag%i",kFlags,i];
        Firebase *updateFlag = [[Firebase alloc] initWithUrl:url];
        [updateFlag updateChildValues:clearNearby];
    }
    
}

#pragma mark - Estimote SDK and Delegate
-(void)setUpEstimoteManager {
    self.beaconManager = [[ESTBeaconManager alloc] init];
    self.beaconManager.delegate = self;
    [self.beaconManager requestAlwaysAuthorization];
    [self.beaconManager startRangingBeaconsInRegion:nil];
}

-(void)beaconManager:(ESTBeaconManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(ESTBeaconRegion *)region {
    BOOL nearFlag1 = NO;
    BOOL nearFlag2 = NO;
    BOOL nearFlag3 = NO;
    
        for (ESTBeacon * beacon in beacons) {
            if (beacon.distance.floatValue>0.0f && beacon.distance.floatValue<1.0f) {
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
    NSLog(nearFlag3 ? @"3 Yes" : @"3 No");
    
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

#pragma mark - Firebase Reset Values
// TODO: flatten json structure
- (void)resetFirebaseGameplay {
    NSDictionary *defaultGameplay = @{ @"Gameplay" : @{
                                            @"Flags" : @{
                                                @"Flag1" : @{
                                                    @"ControlStatus" : @0,
                                                    @"ControllingTeam" : @"-",
                                                    @"NearbyPlayers" : @{
                                                        @"Team1" : @{
                                                            @"player" : @"player"
                                                        },
                                                        @"Team2" : @{
                                                            @"player" : @"player"
                                                        }
                                                    }
                                                },
                                                @"Flag2" : @{
                                                    @"ControlStatus" : @0,
                                                    @"ControllingTeam" : @"-",
                                                    @"NearbyPlayers" : @{
                                                        @"Team1" : @{
                                                            @"player" : @"player"
                                                        },
                                                        @"Team2" : @{
                                                            @"player" : @"player"
                                                        }
                                                    }
                                                },
                                                @"Flag3" : @{
                                                    @"ControlStatus" : @0,
                                                    @"ControllingTeam" : @"-",
                                                    @"NearbyPlayers" : @{
                                                        @"Team1" : @{
                                                            @"player" : @"player"
                                                        },
                                                        @"Team2" : @{
                                                            @"player" : @"player"
                                                        }
                                                    }
                                                }
                                            },
                                            @"RoundDuration" : @300, // 5 minutes
                                            @"RoundScore" : @{
                                                @"Team1" : @0,
                                                @"Team2" : @0
                                            },
                                            @"TimeRemaining" : @20,
                                            @"GameActive" : @"NO",
                                            @"GameOver" : @"NO",
                                            @"GameHost" : @"-"
                                            }
                                       };
    
    NSString *url = kGameSession;
    Firebase *resetGameplay = [[Firebase alloc] initWithUrl:url];
    [resetGameplay updateChildValues:defaultGameplay];
}

-(void)resetFirebaseSettings {
    // TODO: is there a way to just read this from the json file?
    NSDictionary *defaultSettings =    @{ @"Settings" : @{
                                            @"Beacons" : @{
                                                @"Flag1" : @13372,
                                                @"Flag2" : @15271,
                                                @"Flag3" : @20062
                                            },
                                            @"GameName" : @"name",
                                            @"Teams" : @{
                                                @"Team1" : @{
                                                    @"Players" : @{
                                                        @"player" : @"player"
                                                    },
                                                    @"RoundsWon" : @0
                                                },
                                                @"Team2" : @{
                                                    @"Players" : @{
                                                        @"player" : @"player"
                                                    },
                                                    @"RoundsWon" : @0
                                                }
                                            }
                                            }
                                          };
    
    NSString *url = kGameSession;
    Firebase *resetSettings = [[Firebase alloc] initWithUrl:url];
    [resetSettings updateChildValues:defaultSettings];
}

@end
