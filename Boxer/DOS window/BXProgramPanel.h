/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


/// BXProgramPanel defines minor NSView subclasses to customise the appearance and behaviour of
/// program picker panel views.

#import <Cocoa/Cocoa.h>
#import "BXCollectionItemView.h"
#import "BXThemedControls.h"
#import "YRKSpinningProgressIndicator.h"

NS_ASSUME_NONNULL_BEGIN

//Interface Builder tags
enum {
	BXProgramPanelTitle			= 1,
	BXProgramPanelDefaultToggle	= 2,
	BXProgramPanelHide			= 3,
	BXProgramPanelButtons		= 4
};

/// BXProgramPanel is the containing view for all other panel content. This class draws
/// itself as a shaded grey gradient background with a grille at the top.
__deprecated
@interface BXProgramPanel : NSView
@end

/// The tracking item for individual programs in the program panel collection view.
__deprecated
@interface BXProgramItem : BXCollectionItem
{
    NSButton *programButton;
}
@property (strong, nonatomic) NSButton *programButton;
@end

/// Overridden to fix button hover state behaviour when scrolling.
__deprecated
@interface BXProgramItemButton : NSButton
@end

/// Custom button appearance for buttons in the program panel collection view.
__deprecated
@interface BXProgramItemButtonCell : BXThemedButtonCell
{
    BOOL mouseIsInside;
    BOOL programIsDefault;
}
@property (assign, nonatomic) BOOL programIsDefault;
@property (assign, nonatomic) BOOL mouseIsInside;
@end


NS_ASSUME_NONNULL_END
