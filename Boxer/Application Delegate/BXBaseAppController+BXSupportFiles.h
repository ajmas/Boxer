/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXBaseAppController.h"

NS_ASSUME_NONNULL_BEGIN

@class BXGamebox;

/// The \c BXApplicationModes category extends \c BXAppController with methods
/// for looking up Boxer's Application Support files and folders.
@interface BXBaseAppController (BXSupportFiles)

/// Returns Boxer's application support URL.
///
/// If \c createIfMissing is <code>YES</code>, the folder will be created if it does not exist.
/// Returns \c nil and populates \c outError if \c createIfMissing is \c YES but the folder
/// could not be created.
- (nullable NSURL *) supportURLCreatingIfMissing: (BOOL)createIfMissing
										   error: (out NSError **)outError
                                           NS_SWIFT_NAME(supportURL(creatingIfMissing:));

/// Returns Boxer's default location for screenshots and other recordings.
/// If \c createIfMissing is <code>YES</code>, the folder will be created if it does not exist.
/// Returns \c nil and populates \c outError if \c createIfMissing is \c YES but the folder
/// could not be created.
- (nullable NSURL *) recordingsURLCreatingIfMissing: (BOOL)createIfMissing
											  error: (out NSError **)outError
                                              NS_SWIFT_NAME(recordingsURL(creatingIfMissing:));

/// Returns the path to the application support folder where Boxer should
/// store state data for the specified gamebox.
/// If createIfMissing is <code>YES</code>, the folder will be created if it does not exist.
/// Returns \c nil and populates \c outError if \c createIfMissing is \c YES but the folder
/// could not be created.
- (nullable NSURL *) gameStatesURLForGamebox: (BXGamebox *)gamebox
						   creatingIfMissing: (BOOL)createIfMissing
									   error: (out NSError **)outError;

/// Returns the path to the application support folder where Boxer keeps MT-32 ROM files.
/// If \c createIfMissing is <code>YES</code>, the folder will be created if it does not exist.
/// Returns \c nil and populates outError if createIfMissing is YES but the folder
/// could not be created.
- (nullable NSURL *) MT32ROMURLCreatingIfMissing: (BOOL)createIfMissing error: (out NSError **)outError
NS_SWIFT_NAME(mt32ROMURL(creatingIfMissing:));


#pragma mark - MT-32 ROM management

/// Returns the path to the requested ROM file, or \c nil if it is not present.
/// These properties are KVO-compliant and will send out KVO notifications
/// whenever new ROMs are imported.
@property (readonly, copy, nullable) NSURL *MT32ControlROMURL;
@property (readonly, copy, nullable) NSURL *MT32PCMROMURL;

/// Copies the specified MT32 PCM or control ROM into the application support folder,
/// making it accessible via the appropriate URL method above (depending on whether
/// it was a control or PCM ROM).
///
/// Returns the URL of the imported ROM if successful. Returns \c nil and populates \c NSError
/// if the ROM could not be imported or was invalid.
- (nullable NSURL *) importMT32ROMAtURL: (NSURL *)URL error: (out NSError **)outError;

/// Validate that the ROM at the specified URL is valid and suitable for use by Boxer.
- (BOOL) validateMT32ROMAtURL: (inout NSURL *_Nullable*_Nullable)ioValue error: (out NSError **)outError;

/// When given an array of file URLs, scans them for valid ROMs and imports
/// the first pair it finds. Recurses into any folders in the list.
/// Returns \c YES if one or more ROMs were imported, or NO and populates outError
/// if there was a problem (including if the URLs did not contain any MT-32 ROMs.)
- (BOOL) importMT32ROMsFromURLs: (NSArray<NSURL*> *)URLs error: (out NSError **)outError;

@end

NS_ASSUME_NONNULL_END
