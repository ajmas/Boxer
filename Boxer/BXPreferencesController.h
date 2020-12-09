/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "ADBTabbedWindowController.h"


@class BXFilterGallery;
@class BXMT32ROMDropzone;

/// BXPreferencesController manages Boxer's application-wide preferences panel.
/// It is a singleton, and once opened for the first time it stays alive throughout the lifetime of the application.
@interface BXPreferencesController : ADBTabbedWindowController <NSOpenSavePanelDelegate>

/// The filter gallery view from which the user can choose the active rendering style.
@property (strong, nonatomic) IBOutlet BXFilterGallery *filterGallery;

/// The drop-down selector from which the user can choose the location of their games folder.
@property (strong, nonatomic) IBOutlet NSPopUpButton *gamesFolderSelector;

/// The menu item in the drop-down games folder selector that corresponds to the current games folder.
/// The preferences controller keeps the title of this menu item up-to-date whenever the games folder is changed.
@property (strong, nonatomic) IBOutlet NSMenuItem *currentGamesFolderItem;

/// The shelf dropzone onto which the user can drop MT-32 ROMs to install them.
@property (strong, nonatomic) IBOutlet BXMT32ROMDropzone *MT32ROMDropzone;

/// The how-to-find-ROMs instructions shown in the Audio panel when no ROMs have been installed yet.
@property (strong, nonatomic) IBOutlet NSView *missingMT32ROMHelp;

/// The how-to-set-up-your-game instructions shown in the Audio panel when a real MT-32 has been detected as plugged in.
@property (strong, nonatomic) IBOutlet NSView *realMT32Help;

/// The preferences for MT-32 emulation. Only shown when ROMs are installed.
@property (strong, nonatomic) IBOutlet NSView *MT32ROMOptions;

/// The checkbox for enabling/disabling hotkey capture on the Keyboard panel.
@property (strong, nonatomic) IBOutlet NSButton *hotkeyCaptureToggle;

/// The explanation shown beneath the hotkey capture toggle on the Keyboard panel.
@property (strong, nonatomic) IBOutlet NSTextField *hotkeyCaptureDescription;

/// Additional instructions shown on Keyboard panel. If the hotkey capture is available,
/// this shows instructions for activating function keys with the Fn modifier;
/// if the hotkey capture is unavailable, this shows instructions on giving Boxer
/// permission to capture hotkeys.
@property (strong, nonatomic) IBOutlet NSTextField *hotkeyCaptureExtraHelp;

/// The button to open the Accessibility Preferences, shown in the Keyboard panel when Boxer
/// is not allowed to activate its hotkey capture event tap.
@property (strong, nonatomic) IBOutlet NSButton *hotkeyCapturePermissionsButton;


/// Provides a singleton instance of the window controller which stays retained for the lifetime
/// of the application. BXPreferencesController should always be accessed from this singleton.
+ (BXPreferencesController *) controller;


#pragma mark - Filter gallery controls

/// Change the default render filter to match the sender's tag.
/// @note that there is also a @c -toggleRenderingStyle: defined on @c BXDOSWindowController
/// and used by main menu items, which does the same thing. This uses an intentionally different
/// name so as not to collide, as the two sets of controls need to be validated differently.
- (IBAction) toggleDefaultRenderingStyle: (id)sender;

/// Toggle whether the games shelf appearance is applied to the games folder.
/// This will add/remove the appearance from the folder on-the-fly.
- (IBAction) toggleShelfAppearance: (NSButton *)sender;


#pragma mark - General preferences controls

/// Display an OS X open panel for choosing the games folder.
/// @see BXGamesFolderPanelController, which manages the panel and handles its accessory view.
- (IBAction) showGamesFolderChooser: (id)sender;


#pragma mark - Audio controls

/// Reveal Boxer's MT-32 ROMs folder (located inside Application Support) in a Finder window
/// and selects the currently-installed ROMs within that folder.
/// This creates the folder if it doesn't already exist.
/// @see BXBaseAppController+BXSupportFiles @c-MT32ROMURLCreatingIfMissing:error:
- (IBAction) showMT32ROMsInFinder: (id)sender;

/// Show a standard OS X open panel for choosing MT-32 ROMs to install.
- (IBAction) showMT32ROMFileChooser: (id)sender;



#pragma mark - Help

/// Open the appropriate help anchor for the Audio Preferences panel.
- (IBAction) showAudioPreferencesHelp: (id)sender;

/// Open the appropriate help anchor for the Display Preferences panel.
- (IBAction) showDisplayPreferencesHelp: (id)sender;

/// Open the appropriate help anchor for the Keyboard Preferences panel.
- (IBAction) showKeyboardPreferencesHelp: (id)sender;

@end
