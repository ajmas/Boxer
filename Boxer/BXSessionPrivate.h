/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXSessionPrivate declares protected methods for BXSession and its subclasses.

#import "BXSession.h"
#import "BXSession+BXUIControls.h"
#import "BXSession+BXAudioControls.h"
#import "BXSession+BXFileManagement.h"
#import "BXSession+BXPrinting.h"
#import "BXSessionError.h"
#import "ADBUserNotificationDispatcher.h"


#pragma mark - Private constants

extern ADBUserNotificationType const BXPagesReadyNotificationType NS_SWIFT_NAME(ADBUserNotificationType.pagesReady);
extern ADBUserNotificationType const BXDriveImportedNotificationType NS_SWIFT_NAME(ADBUserNotificationType.driveImported);
extern ADBUserNotificationType const BXGameImportedNotificationType NS_SWIFT_NAME(ADBUserNotificationType.gameImported);



@class BXEmulatorConfiguration;
@class BXCloseAlert;
@class BXDrive;

@interface BXSession ()

#pragma mark -
#pragma mark Properties

/// These have been overridden to make them internally writeable
@property (readwrite, retain, nonatomic) NSMutableDictionary *gameSettings;

@property (retain, nonatomic) NSMutableArray *mutableRecentPrograms;

/// The URL to the program that was last launched by user action (i.e. from the program panel or DOS prompt)
/// and the arguments it was launched with.
@property (readwrite, copy, nonatomic) NSURL *launchedProgramURL;
@property (readwrite, copy, nonatomic) NSString *launchedProgramArguments;

@property (readwrite, retain, nonatomic) NSDictionary *drives;
@property (readwrite, retain, nonatomic) NSDictionary *executableURLs;

@property (retain, nonatomic) NSOperationQueue *importQueue;
@property (retain, nonatomic) NSOperationQueue *scanQueue;

@property (retain, nonatomic) NSMutableSet *MT32MessagesReceived;
@property (copy, nonatomic) NSURL *temporaryFolderURL;

/// A cached version of the represented icon for our gamebox. Used by @representedIcon.
@property (retain, nonatomic) NSImage *cachedIcon;

@property (readwrite, assign, getter=isEmulating)	BOOL emulating;
@property (readwrite, nonatomic, assign)            BOOL canOpenURLs;

@property (readwrite, nonatomic, assign, getter=isSuspended)	BOOL suspended;
@property (readwrite, nonatomic, assign, getter=isAutoPaused)	BOOL autoPaused;
@property (readwrite, nonatomic, assign, getter=isInterrupted)	BOOL interrupted;


#pragma mark -
#pragma mark Protected methods

/// Determines what to do after exiting the specified process and returning to the DOS prompt.
/// Called by emulatorDidReturnToShell: once the last process has been shut down.
- (BXSessionProgramCompletionBehavior) _behaviorAfterReturningToShellFromProcess: (NSDictionary *)processInfo;

/// Whether the specified launched program should be recorded in the recent programs list.
- (BOOL) _shouldNoteRecentProgram: (NSDictionary *)processInfo;

/// Whether we should start the emulator as soon as the document is created.
- (BOOL) _shouldStartImmediately;

/// Whether the document should be closed when the emulator process finishes.
/// Normally YES, may be overridden by \c BXSession subclasses.
- (BOOL) _shouldCloseOnEmulatorExit;

/// Whether the session should store the state of its drive queue in the settings for that gamebox.
/// \c YES by default, but will be overridden to \c NO by import sessions.
- (BOOL) _shouldPersistQueuedDrives;

/// Whether the session should relaunch the previous program next time it starts up.
- (BOOL) _shouldPersistPreviousProgram;

/// Whether the user can hold down Option to bypass the regular startup program.
- (BOOL) _shouldAllowSkippingStartupProgram;


/// Create our BXEmulator instance and starts its main loop.
/// Called internally by <code>[BXSession start]</code>, deferred to the end of the main thread's event loop to prevent
/// DOSBox blocking cleanup code.
- (void) _startEmulator;

/// Set up the emulator context with drive mounts and drive-related configuration settings. Called in
/// \c runPreflightCommands at the start of AUTOEXEC.BAT, before any other commands or settings are run.
- (void) _mountDrivesForSession;

/// Populates the session's game settings from the specified dictionary.
/// This will also load any game profile previously recorded in the settings.
- (void) _loadGameSettings: (NSDictionary *)gameSettings;

/// Populates the session's game settings with the settings stored for the specified gamebox.
- (void) _loadGameSettingsForGamebox: (BXGamebox *)gamebox;

/// Returns whether we should cache the specified game profile in our game settings,
/// to avoid needing to redetect it later.
- (BOOL) _shouldPersistGameProfile: (BXGameProfile *)profile;

/// Called once the session has exited to save any DOSBox settings we have changed to the gamebox conf.
- (void) _saveGameboxConfiguration: (BXEmulatorConfiguration *)configuration;

/// Cleans up temporary files after the session is closed.
- (void) _cleanup;


/// Called if DOSBox encounters an unrecoverable error and throws an exception.
- (void) _reportEmulatorException: (NSException *)exception;


/// Callback for close alert. Confirms document close when window is closed or application is shut down.
- (void) _closeAlertDidEnd: (BXCloseAlert *)alert
				returnCode: (NSModalResponse)returnCode
			   contextInfo: (NSInvocation *)callback;

/// Callback for close alert after a windows-only program is failed.
- (void) _windowsOnlyProgramCloseAlertDidEnd: (BXCloseAlert *)alert
								  returnCode: (NSModalResponse)returnCode
								 contextInfo: (void *)contextInfo;
@end


@interface BXSession (BXSuspensionBehaviour)

/// When YES, the session will try to prevent the Mac's display from going to sleep.
@property (assign, nonatomic) BOOL suppressesDisplaySleep;

- (void) _syncSuspendedState;
- (void) _syncAutoPausedState;
- (BOOL) _shouldAutoPause;
- (void) _registerForPauseNotifications;
- (void) _deregisterForPauseNotifications;
- (void) _interruptionWillBegin: (NSNotification *)notification;
- (void) _interruptionDidFinish: (NSNotification *)notification;

- (BOOL) _shouldAutoMountExternalVolumes;

- (BOOL) _shouldSuppressDisplaySleep;
- (void) _syncSuppressesDisplaySleep;

/// Run the application's event loop until the specified date.
/// Pass nil as the date to process pending events and then return immediately.
/// (Note that execution will stay in this method while emulation is suspended,
/// exiting only once the suspension is over and the requested date has past.)
- (void) _processEventsUntilDate: (NSDate *)date;
@end

@interface BXSession (BXFileManagementInternals)

- (void) _registerForFilesystemNotifications;
- (void) _deregisterForFilesystemNotifications;
- (void) _hasActiveImports;

/// Used by \c mountNextDrivesInQueues and \c mountPreviousDrivesInQueues
/// to centralise mounting logic.
- (void) _mountQueuedSiblingsAtOffset: (NSInteger)offset;

/// Whether we should map writes from the specified drive to an external state bundle.
/// Will return \c NO if the drive is read-only or not part of the gamebox.
- (BOOL) _shouldShadowDrive: (BXDrive *)drive;

/// Used for importing and exporting game states while safely overwriting existing ones.
- (BOOL) _copyGameStateFromURL: (NSURL *)sourceURL
                         toURL: (NSURL *)destinationURL
                      outError: (NSError **)outError;

/// Synchronises the specified game state's name, game identifier and version
/// to match those for the current gamebox and Boxer.
/// Called when closing the session and when exporting game state.
- (void) _updateInfoForGameStateAtURL: (NSURL *)stateURL;

@end
