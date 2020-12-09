/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

@class BXDOSWindowController;

enum {
	BXStatusBarInspectorSegment,
	BXStatusBarProgramPanelSegment,
	BXStatusBarMouseLockSegment
};

/// BXStatusBarController manages the main window's status bar and button states.
__deprecated
@interface BXStatusBarController : NSViewController

@property (strong, nonatomic) IBOutlet NSSegmentedControl *statusBarControls;
@property (strong, nonatomic) IBOutlet NSTextField *notificationMessage;
@property (strong, nonatomic) IBOutlet NSButton *mouseLockButton;
@property (strong, nonatomic) IBOutlet NSView *volumeControls;

/// The window controller for the window containing this statusbar
@property (weak, readonly, nonatomic) BXDOSWindowController *controller;

/// Processes the selection/deselection of segments in the segmented button.
/// Called via statusBarControl's action.
- (IBAction) performSegmentedButtonAction: (id) sender;

@end
