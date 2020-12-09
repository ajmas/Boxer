/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXGamebox represents a single Boxer gamebox and offers methods for retrieving and persisting
//bundled drives, configuration files and documentation. It is based on NSBundle but does not
//require that Boxer gameboxes use any standard OS X bundle folder structure.
//(and indeed, gameboxes with an OS X bundle structure haven't been tested.)

//TODO: it is inappropriate to subclass NSBundle for representing a modifiable file package, and we should instead be using an NSFileWrapper directory wrapper.

#import <Cocoa/Cocoa.h>
#import "ADBUndoExtensions.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Gamebox-related error constants

extern NSErrorDomain const BXGameboxErrorDomain;
typedef NS_ERROR_ENUM(BXGameboxErrorDomain, BXLauncherErrors) {
	BXLauncherURLOutsideGameboxError,   //!< Attempted to set gamebox's target path to a location outside the gamebox
    BXGameboxLockedGameboxError,        //!< Attempted a mutation operation that was not possible because the gamebox is locked
    BXDocumentationNotInFolderError,    //!< Attempted a destructive documentation operation on a URL that was not within the gamebox's documentation folder
    BXTargetPathOutsideGameboxError = BXLauncherURLOutsideGameboxError,
};

#pragma mark - Game Info.plist constants

/// The gameInfo key under which we store the game's identifier.
/// Will be an NSString.
extern NSString * const BXGameIdentifierGameInfoKey;

/// The gameInfo key under which we store the type of the game's identifier.
/// Will be an @c NSNumber of @c BXGameIdentifierTypes
extern NSString * const BXGameIdentifierTypeGameInfoKey;

/// The gameInfo key under which we store the default program path,
/// relative to the base folder of the gamebox.
extern NSString * const BXTargetProgramGameInfoKey;

/// The gameInfo key under which we store an array of launcher shortcuts.
/// Each entry in the array is an @c NSDictionary whose keys are listed under
/// "Launcher dictionary constants".
extern NSString * const BXLaunchersGameInfoKey;

/// The gameInfo key under which we store the close-on-exit toggle flag as an @c NSNumber
extern NSString * const BXCloseOnExitGameInfoKey;


#pragma mark - Launcher dictionary constants.

/// The display name for the launcher item.
extern NSString * const BXLauncherTitleKey;

/// The path of the program for the launcher relative to the root of the gamebox.
/// This path is stored in the gamebox's Game Info.plist file.
extern NSString * const BXLauncherRelativePathKey;

/// The absolute URL of the program for the launcher, resolved from
/// @c BXLauncherRelativePathKey at launch time.
///
/// Note that in the case of paths located on disk images, this URL may not be
/// accessible in the DOS filesystem.
extern NSString * const BXLauncherURLKey;

/// Launch-time parameters to pass to the launched program at startup.
extern NSString * const BXLauncherArgsKey;

/// Whether this is the default launcher for this gamebox
/// (i.e. the launcher that will be executed when the gamebox is first launched.)
extern NSString * const BXLauncherIsDefaultKey;


#pragma mark - Filename constants

/// The filename of the symlink pointing to the gamebox's target executable.
/// No longer used.
extern NSString * const BXTargetSymlinkName;

/// The filename and extension of the gamebox configuration file.
extern NSString * const BXConfigurationFileName;
extern NSString * const BXConfigurationFileExtension;

/// The filename and extension of the game info manifest inside the gamebox.
extern NSString * const BXGameInfoFileName;
extern NSString * const BXGameInfoFileExtension;

/// The filename of the documentation folder inside the gamebox.
extern NSString * const BXDocumentationFolderName;


/// The different kinds of game identifiers we can have.
typedef NS_ENUM(NSUInteger, BXGameIdentifierType) {
    /// Manually specified type.
	BXGameIdentifierUserSpecified	= 0,
    ///Standard UUID. Generated for empty gameboxes.
	BXGameIdentifierUUID			= 1,
    ///SHA1 digest of each EXE file in the gamebox.
	BXGameIdentifierEXEDigest		= 2,
    ///Reverse-DNS (net.washboardabs.boxer)-style identifer.
	BXGameIdentifierReverseDNS		= 3,
};

@class BXDrive;

#pragma mark - Interface

/// \c BXGamebox represents a single Boxer gamebox and offers methods for retrieving and persisting
/// bundled drives, configuration files and documentation. It is based on \c NSBundle but does not
/// require that Boxer gameboxes use any standard OS X bundle folder structure.
/// (and indeed, gameboxes with an OS X bundle structure haven't been tested.)
///
/// TODO: it is inappropriate to subclass NSBundle for representing a modifiable file package, and we should instead be using an NSFileWrapper directory wrapper.
@interface BXGamebox : NSBundle <ADBUndoable>

#pragma mark - Properties

/// Returns a dictionary of gamebox metadata loaded from Boxer.plist.
/// Keys in this dictionary also be retrieved with gameInfoForKey:, and set with setGameInfo:forKey:.
@property (readonly, strong, nonatomic, null_resettable) NSDictionary<NSString*,id> *gameInfo;

/// The name of the game, suitable for display. This is the gamebox's filename minus any ".boxer" extension.
@property (readonly, nonatomic) NSString *gameName;

/// The unique identifier of this game.
@property (copy, nonatomic) NSString *gameIdentifier;

/// URLs to bundled drives and images of the specified types.
@property (readonly, nonatomic) NSArray<NSURL*> *hddVolumeURLs;
@property (readonly, nonatomic) NSArray<NSURL*> *cdVolumeURLs;
@property (readonly, nonatomic) NSArray<NSURL*> *floppyVolumeURLs;

/// An array of drives bundled inside this gamebox, ordered by drive letter and filename.
@property (readonly, nonatomic) NSArray<BXDrive *> *bundledDrives;

/// Returns the URL at which the configuration file is stored (which may not yet exist.)
@property (readonly, nonatomic) NSURL *configurationFileURL;

/// Returns the URL of the target program saved under Boxer 1.3.x and below.
@property (readonly, nonatomic, nullable) NSURL *legacyTargetURL;

/// Whether the emulation should finish once the default launcher exits,
/// rather than returning to the DOS prompt. No longer supported.
@property (nonatomic) BOOL closeOnExit;

/// The cover art image for this gamebox. Will be nil if the gamebox has no custom cover art.
/// This is stored internally as the gamebox's OS X icon resource.
@property (copy, nonatomic, nullable) NSImage *coverArt;

/// Program launchers for this gamebox, displayed as favorites in the launch panel.
@property (copy, readonly, nonatomic) NSArray<NSMutableDictionary<NSString*,id>*> *launchers;

/// The default launcher for this gamebox, which should be launched the first time the gamebox is run.
/// This will be @c nil if the gamebox has no default launcher.
@property (readonly, nonatomic, nullable) NSDictionary<NSString*,id> *defaultLauncher;

/// The index in the launchers array of the default launcher.
/// Will be @c NSNotFound if no default launcher has been set.
@property (nonatomic) NSUInteger defaultLauncherIndex;

/// The delegate from whom we will request an undo manager for undoable operations.
@property (weak, nonatomic) id <ADBUndoDelegate> undoDelegate;


#pragma mark - Instance methods

/// Get/set metadata in the gameInfo dictionary.
- (nullable id) gameInfoForKey: (NSString *)key;
- (void) setGameInfo: (nullable id)info forKey: (NSString *)key;

/// Clear resource caches for documentation, gameInfo and executables.
- (void) refresh;


- (void) addLauncher: (NSDictionary<NSString*,id> *)launcher;
- (void) insertLauncher: (NSDictionary<NSString*,id> *)launcher atIndex: (NSUInteger)index;

/// Insert a new launcher item into the launcher list at the specified location,
/// with the specified optional launch arguments.
/// title is optional: if omitted, the filename of the URL will be used.
/// Will raise an assertion if URL does not point to a location within the gamebox.
- (void) insertLauncherWithURL: (NSURL *)URL
                     arguments: (nullable NSString *)launchArguments
                         title: (NSString *)title
                       atIndex: (NSUInteger)index;

/// Same as above, but adds the launcher item at the end of the list.
- (void) addLauncherWithURL: (NSURL *)URL
                  arguments: (nullable NSString *)launchArguments
                      title: (NSString *)title;

/// Remove the specified launcher item from the launchers array.
- (void) removeLauncher: (NSDictionary<NSString*,id> *)launcher;
- (void) removeLauncherAtIndex: (NSUInteger)index;

/// Validates that the specified URL is located within the gamebox
/// and is otherwise suitable as the target of a launcher.
- (BOOL) validateLauncherURL: (NSURL *__nullable*__nonnull)ioValue error: (NSError **)outError;


#pragma mark - Filesystem methods

/// Returns the URLs of all bundled volumes with the specified UTIs.
- (NSArray<NSURL*> *) URLsOfVolumesMatchingTypes: (NSSet<NSString*> *)fileTypes;

/// Returns whether the gamebox's disk representation is currently writable to Boxer:
/// according to the @c NSURLFileIsWritableKey resource property of the bundle's URL.
/// To avoid hitting the filesystem constantly for checks, the result of the check will
/// be cached for a number of seconds.
/// Note that even if this method returns YES, attempts to modify the gamebox's disk state
/// may still fail because of access restrictions.
/// Also note that this is *not* a KVO-compliant property: you must manually check the value each time.
@property (readonly, getter=isWritable) BOOL writable;

@end


#pragma mark - Documentation autodiscovery
typedef NS_ENUM(NSInteger, BXGameboxDocumentationConflictBehaviour) {
    BXGameboxDocumentationRename,
    BXGameboxDocumentationReplace,
};

@interface BXGamebox (BXGameDocumentation)

#pragma mark - Documentation properties

/// Returns an array of documentation found in the gamebox. If the gamebox has a documentation
/// folder, the contents of this folder will be returned; otherwise, the rest of the gamebox
/// will be searched for documentation.
@property (readonly, nonatomic) NSArray<NSURL*> *documentationURLs;

/// Returns the eventual URL for the gamebox's documentation folder. This may not yet exist.
@property (readonly, nonatomic) NSURL *documentationFolderURL;

/// Returns whether the gamebox has a documentation folder of its own.
/// If not, this can be created with @c createDocumentationFolderIfMissingWithError:
/// or @c populateDocumentationFolderCreatingIfMissing:WithError:
@property (readonly, nonatomic) BOOL hasDocumentationFolder;

#pragma mark - Class helper methods

/// Filename patterns for documentation to exclude from searches.
@property (class, readonly, copy) NSSet<NSString*> *documentationExclusions;

/// Returns all the documentation files in the specified filesystem location.
+ (NSArray<NSURL*> *) URLsForDocumentationInLocation: (NSURL *)location searchSubdirectories: (BOOL)searchSubdirs;

/// Returns whether the file at the specified URL appears to be documentation.
+ (BOOL) isDocumentationFileAtURL: (NSURL *)URL;


#pragma mark Documentation operations

/// Empties any documentation cache and forces documentationURLs and hasDocumentationFolder
/// to be re-evaluated. This will signal changes to those properties over KVO.
/// This should be called after making changes to the gamebox's documentation folder outside
/// of the @c BXGamebox API (or e.g. after external filesystem changes to the documentation folder
/// have been detected) to force those changes to be signalled via the API.
- (void) refreshDocumentation;

/// Creates a new empty documentation folder inside the gamebox if one doesn't already exist.
/// This can then be populated with @c populateDocumentationFolderWithError: if desired.
/// Returns @c YES if the folder was created or already existed, or @c NO and populates @c outError
/// if the folder could not be created (which will be the case if the gamebox is locked.)
/// This method registers an undo operation if the folder was created successfully.
- (BOOL) createDocumentationFolderIfMissingWithError: (out NSError **)outError;

/// Moves the documentation folder to the trash along with all its contents.
/// Returns the URL of the folder in the trash, or @c nil if the folder could not be trashed
/// (including if it didn't exist.)
/// This method registers an undo operation if the folder was successfully moved to the trash.
- (nullable NSURL *) trashDocumentationFolderWithError: (NSError **)outError;

/// Populates the documentation folder with symlinks to documentation found elsewhere in the gamebox.
/// If @c createIfMissing is YES, the folder will be created if it doesn't already exist.
/// Returns an array of populated documentation URLs if the folder was populated successfully,
/// or @c NO and returns @c outError if it could not be populated (including if the documentation folder
/// doesn't exist and @c createIfMissing was NO.)
/// This method registers undo operations for creating the folder and populating each documentation file.
- (nullable NSArray<NSURL*> *) populateDocumentationFolderCreatingIfMissing: (BOOL)createIfMissing error: (out NSError **)outError NS_SWIFT_NAME(populateDocumentationFolder(creatingIfMissing:));


/// Copies the file at the specified location into the documentation folder,
/// creating the folder first if it is missing.
/// If @c title is specified, it will be used as the filename for the imported file;
/// otherwise, the file's original name will be used.
/// In the event of a filename collision, @c conflictBehaviour determines whether
/// the file will be replaced or renamed (by appending a number to the filename).
/// Returns the URL of the imported file on success, or @c nil and populates @c outError on failure.
/// This method registers an undo operation if the file was successfully added.
- (nullable NSURL *) addDocumentationFileFromURL: (NSURL *)sourceURL
                                       withTitle: (nullable NSString *)title
                                        ifExists: (BXGameboxDocumentationConflictBehaviour)conflictBehaviour
                                           error: (out NSError **)outError;

/// Adds a symlink to the specified URL into the gamebox's documentation folder,
/// creating the folder first if it is missing.
/// If \c title is specificied, it will be used as the filename for the imported file;
/// otherwise, the file's original name will be used.
/// In the event of a filename collision, @c conflictBehaviour determines whether
/// the file will be replaced or renamed (by appending a number to the filename).
/// Returns the URL of the symlink on success, or @c nil and populates @c outError on failure.
/// This method registers an undo operation if the symlink was successfully added.
- (nullable NSURL *) addDocumentationSymlinkToURL: (NSURL *)sourceURL
                                        withTitle: (nullable NSString *)title
                                         ifExists: (BXGameboxDocumentationConflictBehaviour)conflictBehaviour
                                            error: (out NSError **)outError;

/// Moves the documentation file at the specified URL to the trash (if it is a regular file)
/// or deletes it altogether (if it is a symlink).
/// Returns @c YES on success, and populates @c resultingURL if the file was trashed rather than removed entirely.
/// Returns @c NO and populates @c outError on failure. This method will fail and do nothing if the specified URL
/// is not located within the gamebox's documentation folder.
/// This method registers an undo operation if the file was successfully deleted/moved to the trash.
- (BOOL) removeDocumentationURL: (NSURL *)documentationURL
                   resultingURL: (out NSURL *__nullable*__nullable)resultingURL
                          error: (out NSError **)outError;

/// Returns whether the specified documentation file can be removed from the gamebox.
/// Will return @c NO if the gamebox is locked or the URL is not located within the documentation folder.
- (BOOL) canTrashDocumentationURL: (NSURL *)documentationURL;

/// Returns whether the specified documentation file can be imported into the gamebox.
/// Will return @c NO if the gamebox is locked or has no documentation folder into which the file can go.
- (BOOL) canAddDocumentationFromURL: (NSURL *)documentationURL;

@end


@interface BXGamebox (BXGameboxLegacyPathAPI)

/// The path to the default executable for this gamebox. Will be nil if the gamebox has no target executable.
@property (copy, nonatomic, null_unspecified) NSString *targetPath __deprecated;

/// Returns whether the specified path is valid to be the default target of this gamebox
- (BOOL) validateTargetPath: (id __null_unspecified*__null_unspecified)ioValue error: (NSError **)outError __deprecated;

@end

NS_ASSUME_NONNULL_END
