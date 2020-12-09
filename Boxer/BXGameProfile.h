/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>
#import "BXDrive.h"
#import "ADBFilesystem.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Constants

typedef NS_ENUM(NSInteger, BXReleaseMedium) {
	BXUnknownMedium NS_SWIFT_NAME(unknown) = 0,
	BX525DisketteMedium NS_SWIFT_NAME(diskette525)= 1,
	BX35DisketteMedium NS_SWIFT_NAME(diskette35)= 2,
	BXCDROMMedium NS_SWIFT_NAME(CDROM) = 3
};


/// The default identifier string used for game profiles that don't match a known profile.
extern NSString * const BXGenericProfileIdentifier;

@class ADBScanOperation;
@protocol ADBFilesystemPathAccess, ADBFilesystemPathEnumeration;

/// \c BXGameProfile represents a detected game profile, which describes the game for gamebox creation
/// and specifies custom DOSBox configuration and emulation behaviour.
/// It has helper class methods for detecting a game profile from a filesystem path, and for
/// determining the 'era' of a particular game at a filesystem path.
@interface BXGameProfile : NSObject

#pragma mark -
#pragma mark Properties

/// Returns the relative priority of this profile, for choosing between multiple matching profiles:
/// profiles with higher priority should be considered more "canonical" than lower-priority profiles.
@property (assign, nonatomic) NSUInteger priority;

/// A unique identifier for this profile. Used for quick lookups via +profileWithIdentifier:.
@property (copy, nonatomic) NSString *identifier;

/// The human-readable name of the game this profile represents.
/// Will be \c nil for shared profiles (in which case profileDescription will be available.)
@property (copy, nonatomic, nullable) NSString *gameName;

/// The configuration file(s) to use for this game (sans path and .conf extension),
/// as stored in Resources/Configurations
@property (copy, nonatomic, nullable) NSArray<NSString*> *configurations;

/// The description of what kind of games this game profile covers.
/// Will be nil for game-specific profiles (in which case gameName will be available.)
@property (copy, nonatomic, nullable) NSString *profileDescription;

/// Whether this game needs to be installed from a particular kind of drive
/// (e.g. floppy-disk or CD-ROM).
///
/// If the game has no special requirements, this will be BXDriveAutodetect.
@property (assign, nonatomic) BXDriveType sourceDriveType;

/// The maximum amount of free disk space this game may need to install.
/// Used to assign an appropriate amount of free space on drive C.
/// If the game has no special requirements, this will be BXDefaultFreeSpace.
@property (assign, nonatomic) NSInteger requiredDiskSpace;

/// Whether the game requires a CD-ROM drive to be present in order to start up.
/// If <code>YES</code>, then Boxer will mount a dummy CD-ROM if no other CDs are present.
/// Defaults to <code>NO</code>.
@property (assign, nonatomic) BOOL requiresCDROM;

/// Whether to mount the \b X and \b Y helper drives while importing this game.
/// These drives can confuse the installers for some games,
/// e.g. making them offer the wrong default destination drive.
/// Defaults to <code>YES</code>.
@property (assign, nonatomic) BOOL shouldMountHelperDrivesDuringImport;

/// Whether to mount the \b X drive at all when running this game.
/// Certain games misinterpret the TMP and TEMP variables and need this disabled.
/// Defaults to <code>YES</code>.
@property (assign, nonatomic) BOOL shouldMountTempDrive;

/// The recommended path on drive C into which to import the game files
/// when importing an already-installed copy of this game.
/// Will be @"" if the root folder should be used, or nil if no particular path
/// is recommended.
@property (copy, nonatomic, nullable) NSString *preferredInstallationFolderPath;

/// The type of media upon which this game was likely released: currently this
/// is used only for deciding on cover art, not for emulation decisions.
/// (See sourceDriveType above, which does affect how the game is installed.)
/// Defaults to <code>BXUnknownMedium</code>.
@property (assign, nonatomic) BXReleaseMedium releaseMedium;

/// If a DOSBox configuration file is bundled with a game we're importing,
/// what to import from it: drive mounts, launch commands, and/or configuration settings.
/// These default to YES, but are selectively overridden for e.g. GOG games that are
/// bundled with inappropriate configuration settings.
@property (assign, nonatomic) BOOL shouldImportMountCommands;
@property (assign, nonatomic) BOOL shouldImportLaunchCommands;
@property (assign, nonatomic) BOOL shouldImportSettings;

#pragma mark -
#pragma mark Helper class methods

/// The version of the current profile detection catalogue.
/// This is used for invalidating profiles that were detected and saved under
/// previous versions of Boxer (and which may have since been superseded.)
@property (class, readonly, copy) NSString *catalogueVersion;

/// Returns an array of generic profiles that match multiple games.
/// This corresponds the contents of the BXGenericProfiles key in GameProfiles.plist.
@property (class, readonly, copy) NSArray<NSDictionary<NSString*,id>*> *genericProfiles;

/// Returns an array of game profiles identifying specific games.
/// This corresponds the contents of the BXSpecificGameProfiles key in GameProfiles.plist.
@property (class, readonly, copy) NSArray<NSDictionary<NSString*,id>*> *specificGameProfiles;

/// Returns the kind of distribution medium (CD-ROM, floppy) that the contents of the specified
/// file URL probably used, based on filesize and age of files. Among other things, this is used
/// to decide what kind of bootleg coverart style to use.
+ (BXReleaseMedium) mediumOfGameAtURL: (NSURL *)URL;


#pragma mark -
#pragma mark Initializers

/// Returns a generic profile with no special configuration or game data.
+ (instancetype) genericProfile;

/// Creates a generic profile with no special configuration or game data.
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// Returns the game profile matching the specified identifier,
/// or \c nil if no such profile was found.
+ (nullable instancetype) profileWithIdentifier: (NSString *)identifier;

/// Creates a new profile from the specified GameProfiles.plist-format dictionary.
- (instancetype) initWithDictionary: (NSDictionary<NSString*,id> *)profileDictionary;


/// Detects and returns an appropriate game profile for the specified path,
/// by scanning for telltale files in the file hierarchy starting at basePath.
/// Will return nil if no profile could be found.
/// If \c searchSubfolders is <code>NO</code>, only the base path will be scanned without
/// recursing into subfolders.
+ (nullable instancetype) detectedProfileForPath: (NSString *)basePath
                                searchSubfolders: (BOOL) searchSubfolders;

/// Returns the profile whose telltales match the specified path, or nil if no matching profile
/// is found. This checks only the specified path and does not perform any recursion of directories.
/// Used internally by \c profilesDetectedInContentsOfEnumerator: and <code>profileScanWithEnumerator:</code>.
+ (nullable instancetype) profileMatchingPath: (NSString *)basePath
                                 inFilesystem: (id <ADBFilesystemPathAccess>)filesystem;

/// Returns an enumerator of all game profiles detected by traversing the specified enumerator.
/// (As a convenience this returns an enumerator instead of an array, so that scanning can be
/// terminated prematurely without the cost of a full filesystem search.)
+ (NSEnumerator *) profilesDetectedInContentsOfEnumerator: (id <ADBFilesystemPathEnumeration>)enumerator;

/// Returns a scan operation ready to scan the contents of the specified enumerator.
+ (ADBScanOperation *) profileScanWithEnumerator: (id <ADBFilesystemPathEnumeration>)enumerator;



#pragma mark -
#pragma mark Methods affecting emulation behaviour

/// Returns an customised drive label for the specified drive.
- (NSString *) volumeLabelForDrive: (BXDrive *)drive;

/// Returns whether the file at the specified path is the designated installer for this game.
- (BOOL) isDesignatedInstallerAtPath: (NSString *)path;

/// Returns whether the file at the specified path should be ignored when scanning for installers.
- (BOOL) isIgnoredInstallerAtPath: (NSString *)path;

@end

NS_ASSUME_NONNULL_END
