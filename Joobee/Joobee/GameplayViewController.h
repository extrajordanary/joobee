//
//  ViewController.h
//  Joobee
//
//  Created by Jordan on 9/22/14.
//  Copyright (c) 2014 Byjor. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ESTBeaconManager.h"

@interface GameplayViewController : UIViewController <ESTBeaconManagerDelegate>

@property (nonatomic,strong) ESTBeaconManager * beaconManager;

@end

