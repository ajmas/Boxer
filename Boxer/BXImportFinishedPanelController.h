/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

@class BXImportIconDropzone;
@class BXImportWindowController;

/// \c BXImportFinishedPanelController controls the appearance and behaviour of the final
/// your-gamebox-is-finished panel of the import process.
@interface BXImportFinishedPanelController : NSViewController

/// A back-reference to our owning window controller.
@property (unsafe_unretained, nonatomic) IBOutlet BXImportWindowController *controller;

/// The image well that displays the gamebox icon.
@property (strong, nonatomic) IBOutlet BXImportIconDropzone *iconView;

/// The text field that allows the gamebox's name to be edited.
@property (strong, nonatomic) IBOutlet NSTextField *nameField;

/// The gamebox’s icon itself.
@property (strong, nonatomic) NSImage *gameboxIcon;

/// Reveal the newly-minted gamebox in Finder.
- (IBAction) revealGamebox: (id)sender;

/// Launch the newly-minted gamebox in a new Boxer process.
- (IBAction) launchGamebox: (id)sender;

/// Called when the user drops an image onto the icon view.
- (IBAction) addCoverArt: (NSImageView *)sender;

/// Display help for this stage of the import process.
- (IBAction) showImportFinishedHelp: (id)sender;

/// Search online for cover art for this game.
- (IBAction) searchForCoverArt: (id)sender;
@end

@interface BXImportIconDropzone : NSImageView
{
	BOOL isDragTarget;
}
- (BOOL) isHighlighted;

@end
