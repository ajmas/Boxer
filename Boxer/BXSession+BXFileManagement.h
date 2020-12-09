/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXFileManagement category extends BXSession with methods for controlling the DOS filesystem
//and for responding to relevant changes in the OS X filesystem. It implements Boxer's policies
//for opening files and folders from the OS X filesystem and creating new drives for them.

#import "BXSession.h"
#import "ADBOperationDelegate.h"

#pragma mark -
#pragma mark Constants


/// Options for resolving drive letter conflicts when mounting drives
typedef NS_ENUM(NSInteger, BXDriveConflictBehaviour) {
    BXDriveReplace,     //!< Replace any existing drive at the same drive letter.
    BXDriveQueue,       //!< Queue behind any existing drive at the same drive letter.
    BXDriveReassign     //!< Assign the new drive to the next available free drive letter.
};


/// Bitflag options for @c mountDrive:ifExists:options:error:
typedef NS_OPTIONS(NSUInteger, BXDriveMountOptions) {
    BXDriveKeepWithSameType             = 1U << 0,  //!< Try to mount the drive at the same letter as an
                                                    //!< existing drive of the same type, if it doesn't
                                                    //!< have a more specific drive letter of its own.
                                                    //!< This is currently only respected for CD-ROM and
                                                    //!< floppy drives, and will have no effect in
                                                    //!< combination with BXDriveReassign.
    
    BXDriveAvoidAssigningDriveC         = 1U << 1,  //!< When mounting a drive that doesn't have a specific
                                                    //!< drive letter, avoid giving it drive C. This is used
                                                    //!< during gamebox drive mounting to keep drive C free
                                                    //!< of auto-assigned drives.
                                                    
    
    BXDriveUseBackingImageIfAvailable   = 1U << 2,  //!< If the source path for this drive is a filesystem
                                                    //!< volume, then any backing image for that volume
                                                    //!< will be used instead of the volume itself.
    
    BXDriveUseShadowingIfAvailable      = 1U << 3,  //!< Shadow writes to this drive to a separate location
                                                    //!< if appropriate.

//These options are applicable to both mountDrive:ifExists:options:error and unmountDrive:options:error:.
    BXDriveShowNotifications            = 1U << 4,  //!< Notification bezels will be shown when this drive
                                                    //!< is added/ejected.
    
    BXDriveRemoveExistingFromQueue      = 1U << 5,  //!< Forget about any unmounted/replaced drive altogether,
                                                    //!< rather than letting it remain in the queue to be
                                                    //!< remounted.
    
    BXDriveReplaceWithSiblingFromQueue  = 1U << 6,  //!< When a drive is unmounted, replace it with the next
                                                    //!< drive in the same queue, if available.
                                                    //!< Only applicable to unmountDrive:options:error:.
    
    BXDriveForceUnmounting              = 1U << 7,  //!< Force any unmounted/replaced drive to be unmounted
                                                    //!< even if it appears to be in use.
    
    BXDriveForceUnmountingIfRemovable   = 1U << 8,  //!< Act as BXDriveForceUnmounting if the drive in question
                                                    //!< is a floppy-disk or CD-ROM. Has no effect for hard disks.

    /// Behaviour when mounting a drive via drag-drop or from Add New Drive,
    /// or when inserting a floppy or CD after emulation has started.
    /// Will queue floppy and CD drives with other drives of the same type,
    /// unless a specific drive letter was assigned, and will push the drive
    /// to the front of the queue to make it available immediately.
    BXDefaultDriveMountOptions = BXDriveKeepWithSameType | BXDriveShowNotifications | BXDriveUseBackingImageIfAvailable | BXDriveForceUnmountingIfRemovable | BXDriveUseShadowingIfAvailable,
    
    /// Behaviour when mounting the gamebox's drives at the start of emulation.
    /// Disables notification and searching for backing images, tries to keep
    /// drive C free for specific C drives, and will queue CD and floppy drives
    /// with others of their own kind.
    BXBundledDriveMountOptions = BXDriveKeepWithSameType | BXDriveUseShadowingIfAvailable | BXDriveAvoidAssigningDriveC,
    
    /// Behaviour when mounting OS X floppy/CD volumes at the start of emulation.
    /// Same as default behaviour, but will look for backing images also.
    BXSystemVolumeMountOptions = BXDriveKeepWithSameType | BXDriveUseBackingImageIfAvailable,
    
    /// Behaviour when mounting Boxer's built-in utility and temp drives
    /// at the start of emulation. Will force these to replace existing drives.
    BXBuiltinDriveMountOptions = BXDriveRemoveExistingFromQueue,
    
    /// Options for automounting the target folder/executable of a DOS session.
    BXTargetMountOptions = BXDriveKeepWithSameType | BXDriveUseBackingImageIfAvailable | BXDriveUseShadowingIfAvailable,
    
    /// Options for mounting the source path for a game import.
    BXImportSourceMountOptions = BXDriveKeepWithSameType | BXDriveUseBackingImageIfAvailable,
    
    /// Options for mounting replacement drives when a system volume becomes unavailable.
    BXReplaceWithSiblingDriveMountOptions = BXDriveUseBackingImageIfAvailable,
    
    /// Options for regular drive unmounting.
    BXDefaultDriveUnmountOptions = BXDriveShowNotifications,
    
    /// Behaviour when unmounting drives as a result of a volume being ejected.
    BXVolumeUnmountingDriveUnmountOptions = BXDriveShowNotifications | BXDriveRemoveExistingFromQueue | BXDriveForceUnmounting | BXDriveReplaceWithSiblingFromQueue,
    
    /// Behaviour when unmounting drive temporarily to remove/merge shadow files.
    BXShadowOperationDriveUnmountOptions = BXDriveForceUnmounting,
};


#pragma mark -
#pragma mark Public interface

@class BXDrive;
@class BXDrivesInUseAlert;
@class ADBOperation;
@protocol BXDriveImport;

/// The @c BXFileManagement category extends BXSession with methods for controlling the DOS filesystem
/// and for responding to relevant changes in the OS X filesystem. It implements Boxer's policies
/// for opening files and folders from the OS X filesystem and creating new drives for them.
@interface BXSession (BXFileManagement) <BXEmulatorFileSystemDelegate, ADBOperationDelegate>

/// The 'principal' drive of the session, whose executables we will display in the programs panel
/// This is normally drive C, but otherwise is the first available drive letter with programs on it.
@property (readonly, nonatomic) BXDrive *principalDrive;

/// An array of executable URLs located on the 'principal' drive of the session (normally drive C).
@property (readonly, nonatomic) NSArray *programURLsOnPrincipalDrive;

/// Return whether there are currently any imports/executable scans in progress.
@property (readonly, nonatomic, getter=isImportingDrives) BOOL importingDrives;
@property (readonly, nonatomic, getter=isScanningForExecutables) BOOL scanningForExecutables;

/// A flat array of all queued and mounted drives, ordered by drive letter and then by queue order.
@property (readonly, nonatomic) NSArray<BXDrive*> *allDrives;
/// An array of all mounted drives, ordered by drive letter.
@property (readonly, nonatomic) NSArray<BXDrive*> *mountedDrives;

/// Whether this gamebox has more than one drive queued on a single drive letter, requiring UI for swapping drives.
@property (readonly, nonatomic) BOOL hasDriveQueues;


#pragma mark - Helper class methods

/// Returns the most appropriate base location for a drive to expose the specified path:
/// If path points to a disc image, that will be returned.
/// If path is inside a gamebox or Boxer mountable folder type, that container will be returned.
/// If path is on a CD or floppy volume, then the volume will be returned.
/// Otherwise, the parent folder of the item, or the item itself if it is a folder, will be returned. 
+ (NSURL *) preferredMountPointForURL: (NSURL *)URL;

/// Given an arbitrary target path, returns the most appropriate base location from which to start searching for games:
/// If path is inside a gamebox or Boxer mountable folder type, that container will be returned (and @c shouldRecurse will be YES).
/// If path is on a CD or floppy volume, then the volume will be returned (and @c shouldRecurse will be YES).
/// Otherwise, the parent folder of the item, or the item itself if it is a folder, will be returned (and @c shouldRecurse will be NO).
+ (NSURL *) gameDetectionPointForURL: (NSURL *)URL shouldSearchSubfolders: (BOOL *)shouldRecurse;


#pragma mark - Filetype-related class methods

/// Returns a set of filesnames that should be hidden from DOS directory listings.
/// Used by @c emulator:shouldShowDOSFile:
@property (class, readonly, copy) NSSet<NSString*> *hiddenFilenamePatterns;

/// UTI filetypes of folders that should be used as mount-points for files inside them: if we open a file
/// inside a folder matching one of these types, it will mount that folder as its drive.
/// Used by @c preferredMountPointForPath: which will also prefer the root folders of floppy and CD-ROM volumes.
@property (class, readonly, copy) NSSet<NSString*> *preferredMountPointTypes;

/// The volume formats (as listed in NSWorkspace+ADBMountedVolumes) that will be automatically mounted
/// as new DOS drives when they appear in Finder.
@property (class, readonly, copy) NSSet<NSString*> *automountedVolumeFormats;

/// UTI filetypes that should be given their own drives, even if they are already accessible within an existing DOS drive.
/// This is used by shouldMountDriveForPath: to allow disc images or drive folders inside a gamebox to be mounted as
/// separate drives even when their containing gamebox is already mounted.
@property (class, readonly, copy) NSSet<NSString*> *separatelyMountedTypes;


#pragma mark - Launching programs

/// Open the file at the specified logical URL in DOS with the (optional) specified arguments.
/// If the URL points to an executable, it will be launched with any specified arguments;
/// if it's a directory, the current DOS working directory will be changed to it.
/// If @c clearScreen is YES, this method will clear any previous DOS prompt output before running the program.
/// This is primarily intended for launcher items, and only has an effect if the URL is a program.
/// @c BXSessionProgramCompletionBehavior determines what the session should do after the program exits:
/// See @c BXSessionProgramCompletionBehavior constant definition for details.
/// Returns @c YES on success, or @c NO and populates @c outError if the specified URL could not be launched
/// (e.g. if it was not accessible in DOS.)
- (BOOL) openURLInDOS: (NSURL *)URL
        withArguments: (NSString *)arguments
          clearScreen: (BOOL)clearScreen
         onCompletion: (BXSessionProgramCompletionBehavior)completionBehavior
                error: (out NSError **)outError;

/// Calls the above with no arguments, without clearing the screen, and with automatic exit behavior.
- (BOOL) openURLInDOS: (NSURL *)URL
                error: (out NSError **)outError;

/// Whether the session is in a state where it can open files or folders in DOS.
@property (readonly, nonatomic) BOOL canOpenURLs;


#pragma mark - Managing drive shadowing

/// Returns the path to the bundle where we will store state data for the current gamebox.
@property (readonly, copy) NSURL *currentGameStateURL;

/// Sets/retrieves the Info.plist metadata for the game state at the specified URL. 
- (NSDictionary<NSString*,id> *) infoForGameStateAtURL: (NSURL *)stateURL;
- (BOOL) setInfo: (NSDictionary<NSString*,id> *)info forGameStateAtURL: (NSURL *)stateURL;


/// Returns an appropriate location to which we can shadow write operations for the specified drive.
/// This location may not exist yet, but will be created once it is needed.
- (NSURL *) shadowURLForDrive: (BXDrive *)drive;

/// Revert the contents of the specified drive/all drives to their original values by deleting
/// the shadowed data. Reverting will fail if one or more of the drives are currently in use by DOS.
/// Returns @c YES on success, or @c NO and populates @c outError on failure.
/// After successfully reverting, the emulation should be restarted.
- (BOOL) revertChangesForDrive: (BXDrive *)drive error: (NSError **)outError;
- (BOOL) revertChangesForAllDrivesAndReturnError: (NSError **)outError;

/// Merges any shadowed data for the specified drive/all drives back into the original location.
/// Merging will fail if one or more of the drives are currently in use by DOS.
/// Returns @c YES on success, or @c NO and populates outError on failure.
/// After successfully merging, the emulation should be restarted.
- (BOOL) mergeChangesForDrive: (BXDrive *)drive error: (NSError **)outError;
- (BOOL) mergeChangesForAllDrivesAndReturnError: (NSError **)outError;

/// Returns @c YES if this is a valid state that can be imported for the current gamebox,
/// or @c NO and populates outError with a reason why the state was invalid.
- (BOOL) isValidGameStateAtURL: (NSURL *)URL error: (NSError **)outError;


/// Saves a copy of the current game state as a boxerstate bundle at the specified location,
/// which must be a full path including filename.
/// Returns @c YES on success, or @c NO and populates @c outError on failure.
- (BOOL) exportGameStateToURL: (NSURL *)destinationURL error: (NSError **)outError;

/// Replace the current game state with the state from the specified resource,
/// which must be a valid boxerstate bundle (as created by exportStateFromURL:error:,
/// which can be verified by isValidStateAtURL:.)
/// Returns @c YES on success, or @c NO and populates @c outError on failure.
/// After successfully importing a new state, the emulation should be restarted.
- (BOOL) importGameStateFromURL: (NSURL *)sourceURL error: (NSError **)outError;

/// Whether the session has shadowed data for any of its drives.
/// This is used to toggle the availability of the merge/revert options. 
@property (readonly) BOOL hasShadowedChanges;


#pragma mark - Mounting and queuing drives

/// The window in which we should present drive-related sheets, such as errors and open dialogs.
/// This will be the Drive Inspector panel if it's visible, otherwise the main DOS window.
@property (readonly) NSWindow *windowForDriveSheet;

/// Whether we allow drives to be added or removed.
/// This will return @c YES normally, or @c NO when part of a standalone game bundle.
@property (readonly) BOOL allowsDriveChanges;


/// Adds the specified drive into the appropriate drive queue,
/// without mounting it.
- (void) enqueueDrive: (BXDrive *)drive;

/// Removes the specified drive from the appropriate queue.
/// Will fail if the drive is currently mounted.
- (void) dequeueDrive: (BXDrive *)drive;

/// Replace the specified old drive with the specified new drive
/// at the same position in its queue. Used after importing a drive.
- (void) replaceQueuedDrive: (BXDrive *)oldDrive withDrive: (BXDrive *)newDrive;

/// Returns whether the specified drive is currently mounted in the emulator.
- (BOOL) driveIsMounted: (BXDrive *)drive;

/// Returns the first queued drive that represents the specified logical URL,
/// or @c nil if no such drive is found.
- (BXDrive *) queuedDriveRepresentingURL: (NSURL *)URL;

/// Returns the most appropriate letter at which to mount/queue the specified drive,
/// based on the specified drive mount options. Used by @c mountDrive:ifExists:options:error
/// to choose a letter when a drive has not been given one already.
- (NSString *) preferredLetterForDrive: (BXDrive *)drive
                               options: (BXDriveMountOptions)options;

/// Mounts the specified drive, using the specified mounting options. If successful,
/// returns a drive reflecting the drive actually mounted (this may be different from
/// the drive that was passed in.)
/// Returns @c nil and populates @c outError if the specified drive could not be mounted.
- (BXDrive *) mountDrive: (BXDrive *)drive
                ifExists: (BXDriveConflictBehaviour)conflictBehaviour
                 options: (BXDriveMountOptions)options
                   error: (NSError **)outError;

/// Unmounts the specified drive, using the specified unmounting options.
/// Returns @c YES if the drive could be unmounted, @c NO otherwise.
- (BOOL) unmountDrive: (BXDrive *)drive
              options: (BXDriveMountOptions)options
                error: (NSError **)outError;

/// Returns the index of the currently mounted drive in the queue.
/// Returns the index of the specified drive within its queue.
/// Returns @c NSNotFound if the drive is not in a queue.
- (NSUInteger) indexOfQueuedDrive: (BXDrive *)drive;

/// Returns the next/previous drive in the same queue,
/// at the specified offset from the specified drive.
- (BXDrive *) siblingOfQueuedDrive: (BXDrive *)drive
                          atOffset: (NSInteger)offset;


/// Automount all ISO9660 CD-ROM volumes that are currently mounted in OS X.
/// Will not create new mounts for ones that are already mounted.
/// Returns an array of all drives mounted, which will be empty if none
/// were available to mount.
/// Returns @c nil and populates @c outError if there is an error with mounting
/// any drive.
- (NSArray<BXDrive*> *) mountCDVolumesWithError: (NSError **)outError;

/// Mount all floppy-sized FAT volumes that are currently mounted in OS X.
/// Will not create new mounts for ones that are already mounted.
/// Returns an array of all drives mounted, which will be empty if none
/// were available to mount.
/// Returns @c nil and populates @c outError if there is an error with mounting
/// any drive. 
- (NSArray<BXDrive*> *) mountFloppyVolumesWithError: (NSError **)outError;

/// Mount Boxer's internal toolkit drive at the appropriate drive letter.
/// Returns the mounted drive, or returns @c nil and populates @c outError
/// if the drive could not be mounted.
- (BXDrive *) mountToolkitDriveWithError: (NSError **)outError;

/// Create a temporary folder and mount it at the appropriate drive letter.
/// Returns the mounted drive, or returns @c nil and populates @c outError
/// if the drive could not be mounted.
- (BXDrive *) mountTempDriveWithError: (NSError **)outError;

/// Mounts a dummy CD-ROM drive if no CD drives are already mounted,
/// to fix games that require a CD in the drive at all times.
/// Returns the mounted drive, or returns @c nil and populates @c outError
/// if the drive could not be mounted.
- (BXDrive *) mountDummyCDROMWithError: (NSError **)outError;

/// Unmount the BXDrives in the specified array. Returns @c YES if all drives
/// were unmounted, @c NO if there was an error (in which case @c outError will
/// be populated) or if selectedDrives is empty.
- (BOOL) unmountDrives: (NSArray<BXDrive*> *)drivesToUnmount
               options: (BXDriveMountOptions)options
                 error: (NSError **)outError;


/// Returns whether to allow the specified URL to be mounted as a drive:
/// populating @c outError with the reason why not, if provided.
- (BOOL) validateDriveURL: (NSURL **)ioValue
                    error: (NSError **)outError;

/// Returns whether the specified URL should be mounted as a new drive.
/// Returns @c YES if the URL isn't already DOS-accessible or deserves its
/// own drive anyway, @c NO otherwise.
- (BOOL) shouldMountNewDriveForURL: (NSURL *)URL;

/// Adds a new drive to expose the specified URL, using @c preferredMountPointForURL:
/// to choose an appropriate base location for the drive.
- (BXDrive *) mountDriveForURL: (NSURL *)URL
                      ifExists: (BXDriveConflictBehaviour)conflictBehaviour
                       options: (BXDriveMountOptions)options
                         error: (NSError **)outError;



/// Returns whether the specified drives are allowed to be unmounted.
/// This may display a confirmation sheet and return NO.
- (BOOL) shouldUnmountDrives: (NSArray *)selectedDrives
                usingOptions: (BXDriveMountOptions)options
                      sender: (id)sender;

/// Called when the "are you sure you want to unmount this drive?" alert is closed.
- (void) drivesInUseAlertDidEnd: (BXDrivesInUseAlert *)alert
					 returnCode: (NSInteger)returnCode
                    contextInfo: (NSDictionary *)contextInfo;


#pragma mark -
#pragma mark Executable scanning

/// Returns a scan operation for the specified drive.
- (ADBOperation *) executableScanForDrive: (BXDrive *)drive
                         startImmediately: (BOOL)start;

/// Aborts the scan for the specified drive.
/// Returns @c YES if a scan was aborted, @c NO if no scan was in progress.
- (BOOL) cancelExecutableScanForDrive: (BXDrive *)drive;

/// Returns any ongoing executable scan for the specified specified drive,
/// or @c nil if no scan is in progress.
- (ADBOperation *) activeExecutableScanForDrive: (BXDrive *)drive;

/// Called when an executable scan has finished.
/// Updates the executable cache for the specified drive.
- (void) executableScanDidFinish: (NSNotification *)theNotification;


#pragma mark -
#pragma mark Drive importing

/// Returns whether the specified drive is located inside the session's gamebox.
- (BOOL) driveIsBundled: (BXDrive *)drive;

/// Returns whether a drive with the same destination name is located inside
/// the session's gamebox, which probably means the drive has been previously imported.
/// NOTE: we no longer use this check because of too many false positives.
/// Since it only checks label and not drive contents, it will erroneously report that
/// nonidentical CDs have already been imported if they have the same volume name as an existing CD.
/// (This was especially common with unlabelled CDs, which appear in Finder as "Untitled".)
- (BOOL) equivalentDriveIsBundled: (BXDrive *)drive;

/// Returns any ongoing import operation for the specified drive,
/// or @c nil if no import is in progress.
- (ADBOperation <BXDriveImport> *) activeImportOperationForDrive: (BXDrive *)drive;

/// Returns whether the specified drive can be imported.
/// Will be @c NO if:
/// - there is no gamebox for this session
/// - the drive is a DOSBox/Boxer-internal drive
/// - the drive has already been or is currently being imported
- (BOOL) canImportDrive: (BXDrive *)drive;


/// Returns an import operation that will import the specified drive to a bundled
/// drive folder in the gamebox. If @c start is YES, the operation will be started
/// immediately; otherwise it should be passed to @c startImportOperation: later
/// (which performs additional preparations for the import).
- (ADBOperation <BXDriveImport> *) importOperationForDrive: (BXDrive *)drive
                                          startImmediately: (BOOL)start;

/// Start an import operation previously created by @c importOperationForDrive:startImmediately:
/// This will unmount any drive that will be unavailable during the operation.
- (void) startImportOperation: (ADBOperation <BXDriveImport> *)operation;

/// Cancel the in-progress import of the specified drive. Returns @c YES if the import was cancelled,
/// \c NO if the import had already finished or the drive was not being imported.
- (BOOL) cancelImportForDrive: (BXDrive *)drive;

/// Called when a drive has finished importing. Replaces the source drive with the imported version.
- (void) driveImportDidFinish: (NSNotification *)theNotification;

#pragma mark - Captures

/// Returns a file URL suitable for capturing a file of the specified type and extension.
- (NSURL *) URLForCaptureOfType: (NSString *)typeDescription
                  fileExtension: (NSString *)extension;

@end
