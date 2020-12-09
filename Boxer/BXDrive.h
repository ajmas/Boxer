/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Constants

typedef NS_ENUM(NSInteger, BXDriveType) {
	BXDriveAutodetect	= -1,
	BXDriveHardDisk		= 0,
	BXDriveFloppyDisk	= 1,
	BXDriveCDROM		= 2,
	BXDriveVirtual		= 3
};

/// Setting freeSpace to @c BXDefaultFreeSpace indicates that the drive should use whatever free space DOSBox thinks is best.
#define BXDefaultFreeSpace -1


#pragma mark -
#pragma mark Interface

@protocol ADBFilesystemPathAccess, ADBFilesystemLogicalURLAccess;

/// \c BXDrive represents a single DOS drive and encapsulates all the data needed to mount the drive
/// and locate it on the OS X filesystem. BXDrives are mounted via ADBFilesystem's @c mountDrive: method.
@interface BXDrive : NSObject

#pragma mark - Properties

/// The location on the OS X filesystem of this drive's contents.
/// This is the canonical location of the drive and is used when resolving absolute
/// URLs to DOS filesystem paths. It may or may not be the same as the location that
/// actually gets mounted in DOSBox: see @c mountPointURL below.
///
/// Several properties are derived automatically from the source URL: Changing the
/// source URL will recalculate mountPointURL, letter, title, volumeLabel and type
/// unless these have been explicitly overridden.
@property (copy, nonatomic, nullable) NSURL *sourceURL;

/// The OS X filesystem location that will be mounted in DOSBox.
/// Usually this is the same as the source URL, but differs for e.g. CD-ROM bundles.
@property (copy, nonatomic, nullable) NSURL *mountPointURL;

/// An optional location on the OS X filesystem to which we will perform
/// shadow write operations for this drive. That is, any files that are
/// opened for modification on this drive will be silently written to this
/// location instead of creating/modifying files in the original location.
@property (copy, nonatomic, nullable) NSURL *shadowURL;


/// The DOS drive letter under which this drive will be mounted.
/// If nil, @c BXEmulator will choose an appropriate drive letter at mount time
/// (and update this property with the chosen letter).
@property (copy, nonatomic, nullable) NSString *letter;

/// The display title to show for this drive in drive lists. Automatically derived
/// from the filename of the source URL, but can be modified.
@property (copy, nonatomic, nullable) NSString *title;

/// The volume label to use for this drive in DOS. Automatically derived from the filename
/// of the source URL, but can be modified. For image-based drives this value is ignored,
/// since the volume label is stored inside the image itself.
@property (copy, nonatomic, nullable) NSString *volumeLabel;

/// The volume label that the drive ended up with after mounting in DOS.
/// This is populated by BXEmulator when the drive is first mounted and will be a munged
/// version of the above: cropped to 11 characters and uppercased for most drive types.
@property (copy, nonatomic, nullable) NSString *DOSVolumeLabel;

/// The amount of free disk space to report for the drive, in bytes. Defaults to
/// BXDefaultFreeSpace: which is ~250MB for hard disks, 1.44MB for floppies and 0B for CDROMs.
/// Note that this is not an enforced limit: it only affects how much free space is reported
/// to DOS programs.
@property (nonatomic) NSInteger freeSpace;

/// Whether to use SDL CD-ROM audio: only relevant for folders mounted as CD-ROM drives.
/// If YES, DOS emulation will read CD audio for this drive from the first audio CD volume mounted in OS X.
@property (nonatomic) BOOL usesCDAudio;

/// Whether to prevent DOS from writing to the OS X filesystem representing this drive. Defaults to NO.
/// This property is ignored for CD-ROM drives and DOSBox's internal Z drive,
/// which are always treated as read-only.
@property (nonatomic, getter=isReadOnly) BOOL readOnly;

/// Whether to protect this drive from being unmounted from Boxer's drive manager UI. Defaults to NO.
/// Ignored for DOSBox's internal Z drive, which is always locked.
@property (nonatomic, getter=isLocked) BOOL locked;

/// Whether to hide this drive from Boxer's drive manager UI. Defaults to NO.
/// Ignored for DOSBox's internal Z drive, which is always hidden.
@property (nonatomic, getter=isHidden) BOOL hidden;

/// Whether this drive is currently mounted in an emulation session.
/// This is merely a flag to make displaying the state of a drive easier; setting it to @c YES
/// will not actually mount the drive, just indicate that it is mounted somewhere.
@property (nonatomic, getter=isMounted) BOOL mounted;



#pragma mark - Immutable properties

/// The type of DOS drive that was mounted.
///
/// Determined at drive creation and cannot be changed afterward.
@property (readonly, nonatomic) BXDriveType type;

/// Returns whether this drive is the specified drive type.
@property (readonly, nonatomic) BOOL isVirtual;
@property (readonly, nonatomic) BOOL isCDROM;
@property (readonly, nonatomic) BOOL isFloppy;
@property (readonly, nonatomic) BOOL isHardDisk;

/// A filesystem instance appropriate for the backing medium of this drive.
@property (readonly, strong, nonatomic) id <ADBFilesystemPathAccess, ADBFilesystemLogicalURLAccess> filesystem;

/// A localized human-readable title for the drive's type, for display in the UI.
@property (readonly, nonatomic) NSString *localizedTypeDescription;


#pragma mark - Class methods

/// Returns a localised descriptive name for the specified drive type. e.g. @"hard disk", @"CD-ROM" etc. 
+ (NSString *) localizedDescriptionForType: (BXDriveType)driveType;

/// Determines the most appropriate drive type for the specified file or folder. This is based on:
///
/// 1. the file's type identifier: e.g. disk images will be treated as CD-ROM or floppy drives;
/// 2. the filesystem of the URL's volume: e.g. folders located on a CD-ROM volume will be detected as CD-ROMs.
+ (BXDriveType) preferredTypeForContentsOfURL: (NSURL *)URL;

/// Determines a suitable DOS volume label for the specified location.
///
/// For regular folders and CD-ROM volumes, this will be their filename;
/// For .floppy, .cdrom, .cdmedia and .harddisk folders, this will be their filename
/// minus extension and parsed drive letter (see @c preferredDriveLetterForContentsOfURL: below.)
+ (NSString *) preferredVolumeLabelForContentsOfURL: (NSURL *)URL;

/// Determines a suitable display title for the specified location.
/// This is currently the base filename of the path including file extension.
+ (NSString *) preferredTitleForContentsOfURL: (NSURL *)URL;

/// Determines a recommended drive letter from the specified location,
/// or @c nil if no specific drive letter is appropriate.
///
/// If the location is a disk image or a Boxer mountable folder, and the filename starts with a single
/// letter followed by a space, this will be parsed out and used as the drive letter.
+ (nullable NSString *) preferredDriveLetterForContentsOfURL: (NSURL *)URL;

/// Returns the location that would actually be mounted when creating a drive with the specified source URL.
/// This is usually the same as the source URL itself, but will differ for e.g. CD-ROM bundles.
+ (NSURL *) mountPointForContentsOfURL: (NSURL *)URL;


#pragma mark - Constructors

/// Returns a newly-minted drive instance representing the contents of the specified URL.
/// If driveLetter is specified, this will be used; if it is left nil, an appropriate drive
/// letter will be determined when the drive is first mounted.
/// If driveType is specified, a drive of that type will be created; if it is BXDriveTypeAuto,
/// the most appropriate type will be determined from the contents of the URL.
- (instancetype) initWithContentsOfURL: (nullable NSURL *)sourceURL
                                letter: (nullable NSString *)driveLetter
                                  type: (BXDriveType)driveType;

+ (instancetype) driveWithContentsOfURL: (nullable NSURL *)sourceURL
                                 letter: (nullable NSString *)driveLetter
                                   type: (BXDriveType)driveType;

/// Returns a marker for a DOSBox internal virtual drive.
/// Such drives do not have source URLs or filesystems, and cannot be used to resolve absolute URLs
/// to DOS filesystem paths.
+ (instancetype) virtualDriveWithLetter: (NSString *)letter;

#pragma mark - Path lookups

/// Returns whether the specified filesystem URL is equivalent to this drive.
/// This is mostly used for determining whether a location is already mounted as a DOS drive.
- (BOOL) representsLogicalURL: (NSURL *)URL;

/// Returns whether the specified logical URL would be accessible in DOS from this drive.
- (BOOL) exposesLogicalURL: (NSURL *)URL;

/// Returns the location of the specified logical URL relative to the filesystem of the drive:
/// or @c nil if the specified location is not contained on this drive.
/// Used by @c BXDOSFileSystem for matching OS X filesystem paths with DOS filesystem paths.
- (nullable NSString *) relativeLocationOfLogicalURL: (NSURL *)URL;

/// Returns a logical URL representing the specified DOS path, as constructed by the drive's filesystem.
/// Note that this is not the same as a local filesystem path.
- (nullable NSURL *) logicalURLForDOSPath: (NSString *)dosPath;

/// Indicates that the specified URL represents the same resource as the contents of this drive.
/// This is used by the drive's filesystem to correctly resolve URLs to resources in different apparent locations.
/// Mainly this is of use for drives representing disk images: so that if the image is mounted
/// as a folder in OS X, the drive will treat locations within the mounted folder as being contained
/// within the drive.
- (void) addEquivalentURL: (NSURL *)URL;

/// Removes an equivalent URL mapping previously added by addEquivalentURL:.
- (void) removeEquivalentURL: (NSURL *)URL;


#pragma mark - Sort comparisons

/// Sorts drives based on how deep their source URL is.
/// This is used for resolving the proper drive to use for locations on nested drives.
- (NSComparisonResult) sourceDepthCompare: (BXDrive *)comparison;

/// Sorts drives by drive letter.
- (NSComparisonResult) letterCompare: (BXDrive *)comparison;

@end

NS_ASSUME_NONNULL_END
