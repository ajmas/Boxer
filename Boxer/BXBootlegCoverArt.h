/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

/// BXBootlegCoverArt is similar to BXCoverArt, but creates generic cover art based on a title string
/// rather than a box image. Implementing classes create artwork to resemble bootleg floppy disks and
/// CD-ROM jewel-cases.
@protocol BXBootlegCoverArt <NSObject>

/// Return a new BXBootlegCoverArt implementor using the specified title.
- (instancetype) initWithTitle: (NSString *)coverTitle;

/// The game title to display on this cover art.
@property (copy, nonatomic) NSString *title;

/// Draws the source image as cover art into the specified frame in the current graphics context.
- (void) drawInRect: (NSRect)frame;

/// Returns a cover art image representation from the instance's title rendered at the specified size.
- (NSImageRep *) representationForSize: (NSSize)iconSize;

/// Returns a cover art image rendered from the instance's title, suitable for use as an OS X icon.
- (NSImage *) coverArt;

/// Returns a cover art image rendered from the specified title, suitable for use as an OS X icon.
+ (NSImage *) coverArtWithTitle: (NSString *)title;

@end


@interface BXJewelCase : NSObject <BXBootlegCoverArt>

/// The game title to display on this cover art.
@property (copy, nonatomic) NSString *title;

/// Returns the font family name used for printing the title.
+ (NSString *) fontName;

/// Returns the color used for printing the title.
+ (NSColor *) textColor;

/// Returns the line height and font size used for printing the title.
+ (CGFloat) lineHeightForSize:	(NSSize)size;
+ (CGFloat) fontSizeForSize:	(NSSize)size;

/// Returns a dictionary of \c NSAttributedString text attributes used for printing the title.
/// This is a collection of the return values of the methods above.
+ (NSDictionary<NSAttributedStringKey,id> *) textAttributesForSize: (NSSize)size;

/// Returns the image to render underneath the text.
+ (NSImage *) baseLayerForSize: (NSSize)size;

/// Returns the image to render over the top of the text.
+ (NSImage *) topLayerForSize: (NSSize)size;

/// Returns the region of the image in which to print the text.
/// Will be \c NSZeroRect if text should not be printed at this size.
+ (NSRect) textRegionForRect: (NSRect)rect;

@end

@interface BX35Diskette : BXJewelCase
@end

@interface BX525Diskette : BXJewelCase
@end
