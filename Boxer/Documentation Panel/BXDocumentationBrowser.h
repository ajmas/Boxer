/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "BXCollectionItemView.h"

@class BXSession;
@class BXDocumentationList;
@protocol BXDocumentationBrowserDelegate;

/// BXDocumentationBrowser manages the list of documentation for the gamebox.
@interface BXDocumentationBrowser : NSViewController <NSCollectionViewDelegate, NSDraggingDestination>

#pragma mark - Properties

/// The delegate to which we will send \c BXDocumentationBrowserDelegate messages.
@property (weak, nonatomic) IBOutlet id <BXDocumentationBrowserDelegate> delegate;

/// The scrolling wrapper in which our documenation list is displayed.
@property (strong, nonatomic) IBOutlet NSScrollView *documentationScrollView;

/// The title at the top of the browser.
@property (strong, nonatomic) IBOutlet NSTextField *titleLabel;

/// The help text displayed at the bottom of the browser.
@property (strong, nonatomic) IBOutlet NSTextField *helpTextLabel;

/// The collection view in which our documentation will be displayed.
@property (strong, nonatomic) IBOutlet BXDocumentationList *documentationList;

/// An array of NSURLs for the documentation files included in this gamebox.
/// This is mapped directly to the documentation URLs reported by the gamebox.
@property (readonly, copy, nonatomic) NSArray<NSURL*> *documentationURLs;

/// An array of criteria for how the documentation files should be sorted in the UI.
/// Documentation will be sorted by type and then by name, to group similar types
/// of documentation files together.
@property (readonly, nonatomic) NSArray<NSSortDescriptor*> *sortCriteria;

/// The currently selected documentation items. Normally, only one item can be selected at a time.
@property (strong, nonatomic) NSIndexSet *documentationSelectionIndexes;

/// An array of the currently-selected documentation items.
@property (copy, readonly, nonatomic) NSArray<NSURL*> *selectedDocumentationURLs;

/// The ideal size for displaying the browser without clipping.
/// This varies based on the number of documentation items and the length of the title.
@property (readonly, nonatomic) NSSize idealContentSize;

/// The text that will be displayed in the help text label at the foot of the view.
/// Changes depending on how many documentation items there are and whether adding new documentation is possible.
@property (readonly, nonatomic) NSString *helpText;

/// Whether we are able to add or remove documentation from the gamebox.
/// This is determined from the locked status of the gamebox,
/// the presence of a Documentation folder in the gamebox, and whether we are a standalone game app.
@property (readonly, nonatomic) BOOL canModifyDocumentation;

#pragma mark - Constructors

/// Returns a newly-created BXDocumentationListController instance
/// whose UI is loaded from DocumentationList.xib.
+ (instancetype) browserForSession: (BXSession *)session;
- (instancetype) initWithSession: (BXSession *)session;


#pragma mark - Interface actions

- (IBAction) openSelectedDocumentationItems: (id)sender;
- (IBAction) revealSelectedDocumentationItemsInFinder: (id)sender;
- (IBAction) trashSelectedDocumentationItems: (id)sender;

/// Helper methods for adding/removing documentation items.
/// These will register undo actions and will present error sheets if importing/removal fails.
- (BOOL) removeDocumentationURLs: (NSArray<NSURL*> *)URLs;
- (BOOL) importDocumentationURLs: (NSArray<NSURL*> *)URLs;


#pragma mark - Drag-dropping

/// Responding to attempts to drag new files into the documentation list.
- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender;
- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender;


#pragma mark - UI layout

/// Returns the ideal size for the browser if it contained the specified number of documentation items.
- (NSSize) idealContentSizeForNumberOfItems: (NSUInteger)numberOfItems;

@end

/// The \c BXDocumentationPreviews category expands BXDocumentationListController to allow documentation to be shown in a QuickLook preview panel.
@interface BXDocumentationBrowser (BXDocumentationPreviews) <QLPreviewPanelDelegate, QLPreviewPanelDataSource>

/// Displays a QuickLook preview panel for the specified documentation items.
- (IBAction) previewSelectedDocumentationItems: (id)sender;

@end


@protocol BXDocumentationBrowserDelegate <NSObject>

@optional

/// Called when the user presses the ESC key.
- (void) documentationBrowserDidCancel: (BXDocumentationBrowser *)browser;

/// Called when the user opens one or more documentation files from the list.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser didOpenURLs: (NSArray<NSURL*> *)URLs;

/// Called when the user opens a QuickLook preview on the specified items.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser didPreviewURLs: (NSArray<NSURL*> *)URLs;

/// Called when the user shows the specified items in Finder.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser didRevealURLs: (NSArray<NSURL*> *)URLs;

/// Called when the browser has encountered an error that it cannot deal with and will present it.
/// This is analoguous to willPresentError:, and likewise you can return a different error to customize
/// the error that will be displayed.
- (NSError *) documentationBrowser: (BXDocumentationBrowser *)browser willPresentError: (NSError *)error;

/// Called when the browser wants to present an error, to return the window in which it should present the error modally.
/// If this returns nil, or is unimplemented, the error will be presented as application-modal instead.
- (NSWindow *) documentationBrowser: (BXDocumentationBrowser *)browser windowForModalError: (NSError *)error;

/// Called just before the browser updates with new URLs. At this point the browser's documentationURLs property,
/// and the collection view's content property, will still contain the old URLs.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser
           willUpdateFromURLs: (NSArray<NSURL*> *)oldURLs
                       toURLs: (NSArray<NSURL*> *)URLs;

/// Called just after the browser updates with new URLs. At this point both the browser's documentationURLs
/// and the collection view's contents will have changed to the new URLs.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser
            didUpdateFromURLs: (NSArray<NSURL*> *)oldURLs
                       toURLs: (NSArray<NSURL*> *)URLs;

@end



/// BXDocumentationItem manages each individual documentation file listed in the documentation popup.
@interface BXDocumentationItem : BXCollectionItem

/// The icon for the documentation file.
///
/// This will initially be the Finder file icon, but will be replaced with a Spotlight image preview
/// asynchronously.
@property (strong, nonatomic) NSImage *icon;

/// The display name of the documentation file.
///
/// This will be the filename of the documentation file sans extension.
@property (copy, readonly, nonatomic) NSString *displayName;

@end

/// Custom appearance for documentation items. Highlights the background when selected.
@interface BXDocumentationWrapper : BXCollectionItemView
@end


/// Custom subclass for documentation list collection view to tweak keyboard and mouse handling
/// and to calculate our ideal display size.
@interface BXDocumentationList : NSCollectionView

/// Returns the size the documentation list will need to be in order to display
/// the specified number of items without scrolling.
- (NSSize) minContentSizeForNumberOfItems: (NSUInteger)numItems;

/// Returns the specified width rounded up to match cleanly to one of our own possible widths.
///
/// Used by <code>BXDocumentationBrowser idealContentSizeForNumberOfItems:</code> to ensure that it shinkwraps
/// the browser to a size that can cleanly accommodate each column of documentation.
- (CGFloat) snappedWidthForTargetWidth: (CGFloat)targetWidth;

@end


/// A horizontal divider that fades from grey at the center to transparent at the edges.
@interface BXDocumentationDivider : NSView
@end
