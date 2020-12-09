/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXBezelController is a singleton that manages a translucent notification bezel.


#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Constants

typedef NS_ENUM(NSInteger, BXBezelPriority) {
    BXBezelPriorityLow,
    BXBezelPriorityNormal,
    BXBezelPriorityHigh
};

//XIB view flags for indicating different view roles within a bezel
NS_ENUM(NSInteger) {
    BXBezelMessage          = 7,    //!< Message imparted by the bezel
    BXBezelIcon             = 1,    //!< Decorative icon for the bezel
    BXBezelLevel            = 2,    //!< Level indicator
    BXBezelLevelStatus      = 3,    //!< Label describing the status indicated in the level indicator
    
    BXBezelDriveAction      = 4,    //!< Label describing what's happening to the drive
    BXBezelDriveTitle       = 5,    //!< Display title of the drive
    
    BXBezelDriveFromIcon    = 1,    //!< The icon of the drive we are switching from
    BXBezelDriveToIcon      = 6     //!< The icon of the drive we are switching to
};

@class BXDrive;
@class BXGamebox;
/// BXBezelController is a singleton that manages a translucent notification bezel.
@interface BXBezelController : NSWindowController

#pragma mark -
#pragma mark Properties

/// The bezel view used for drive inserted/ejected/imported notifications.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *driveAddedBezel;
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *driveSwappedBezel;
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *driveRemovedBezel;
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *driveImportedBezel;

/// The bezel used for fullscreen toggle notifications.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *fullscreenBezel;

/// The bezel used for notifying the user that the joystick is being ignored.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *joystickIgnoredBezel;

/// The bezel view used for CPU speed notifications.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *CPUSpeedBezel;

/// The bezel view used for flightstick throttle notifications.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *throttleBezel;

/// The bezel view used for volume notifications.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *volumeBezel;

/// The bezel view used for MT-32 LCD messages.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *MT32MessageBezel;
/// The bezel view used for notifying the user that they need an MT-32 to hear proper music.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *MT32MissingBezel;

/// Screenshot bezel views.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *screenshotBezel;

/// Pause/play/fast-forward bezel views.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *pauseBezel;
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *playBezel;
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *fastForwardBezel;

/// Numpad simulation bezels.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *numpadActiveBezel;
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *numpadInactiveBezel;

/// Numlock toggle bezels.
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *numlockActiveBezel;
@property (strong, nonatomic, null_unspecified) IBOutlet NSView *numlockInactiveBezel;

@property (strong, nonatomic, null_unspecified) IBOutlet NSView *mouseLockedBezel;

/// The last bezel that was displayed.
@property (readonly, nonatomic, nullable) NSView *currentBezel;

#pragma mark -
#pragma mark Class methods

/// The singleton controller to which all bezel requests should be directed.
@property (class, readonly, strong) id controller;

/// Returns the icon image to use for representing the specified drive.
+ (nullable NSImage *) bezelIconForDrive: (BXDrive *)drive;

#pragma mark -
#pragma mark Methods

/// Whether to show or suppress drive notifications.
/// This will return NO if the Drives Inspector panel is open.
- (BOOL) shouldShowDriveNotifications;

- (void) showDriveAddedBezelForDrive: (BXDrive *)drive;
- (void) showDriveRemovedBezelForDrive: (BXDrive *)drive;
- (void) showDriveSwappedBezelFromDrive: (BXDrive *)fromDrive
                                toDrive: (BXDrive *)toDrive;
- (void) showDriveImportedBezelForDrive: (BXDrive *)drive
                              toGamebox: (BXGamebox *)gamebox;

- (void) showPauseBezel;
- (void) showPlayBezel;
- (void) showFastForwardBezel;

- (void) showScreenshotBezel;

- (void) showNumpadActiveBezel;
- (void) showNumpadInactiveBezel;

- (void) showNumlockActiveBezel;
- (void) showNumlockInactiveBezel;

- (void) showFullscreenBezel;
- (void) showJoystickIgnoredBezel;

- (void) showMT32BezelForMessage: (NSString *)message;
- (void) showMT32MissingBezel;

- (void) showCPUSpeedBezelForSpeed: (NSInteger)cpuSpeed;
- (void) showThrottleBezelForValue: (float)throttleValue;

- (void) showVolumeBezelForVolume: (float)volume;

- (BOOL) showBezel: (NSView *)bezel
       forDuration: (NSTimeInterval)duration
          priority: (BXBezelPriority)priority;

- (void) showMouseLockedBezel;

- (void) hideBezel;
- (void) centerBezel;

@end

NS_ASSUME_NONNULL_END
