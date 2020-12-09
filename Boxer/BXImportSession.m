/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//IMPLEMENTATION NOTE: this class is currently a conceptual mess, and needs serious restructuring:
//- The UI is responsible for ensuring that the import workflow is handled correctly and that
//  steps are performed in the correct order. Instead of saying "OK, continue with the next
//  logical step of the operation", the UI says "OK, now run this specific step." Bad.
//- The import process cannot currently be done unattended as it relies on UI confirmation.
//  This prevents it being easily scriptable.
//- The life cycle of this class goes against the grain of Cocoa's document architecture:
//  'blank' documents are created in order to show the what-do-you-want-to-import picker,
//  and then populated after that with a file URL once the user has chosen a source.
//  Instead, the initial source picker (which is conceptually identical to an Open File dialog)
//  should be handled by a separate class that creates fully prepared import sessions to continue
//  the import process.

#import "BXImportSession.h"
#import "BXSessionPrivate.h"
#import "BXEmulator+BXDOSFileSystem.h"

#import "BXDOSWindowControllerLion.h"
#import "BXImportWindowController.h"

#import "BXAppController+BXGamesFolder.h"
#import "BXFileTypes.h"
#import "BXInspectorController.h"
#import "BXGameProfile.h"
#import "BXGamebox.h"
#import "BXDrive.h"
#import "BXCloseAlert.h"

#import "ADBFileTransferSet.h"
#import "ADBSingleFileTransfer.h"
#import "BXDriveImport.h"
#import "BXBinCueImageImport.h"

#import "BXImportSession+BXImportPolicies.h"
#import "BXSession+BXFileManagement.h"

#import "NSWorkspace+ADBFileTypes.h"
#import "NSWorkspace+ADBMountedVolumes.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "NSFileManager+ADBUniqueFilenames.h"
#import "NSString+ADBPaths.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSError+ADBErrorHelpers.h"

#import "BXInstallerScan.h"
#import "BXEmulatorConfiguration.h"

#import "ADBPathEnumerator.h"

#import "ADBAppKitVersionHelpers.h"
#import "NSObject+ADBPerformExtensions.h"

#import "ADBUserNotificationDispatcher.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXImportSession ()

@property (readwrite, assign, nonatomic) BXImportStage importStage;
@property (readwrite, assign, nonatomic) ADBOperationProgress stageProgress;
@property (readwrite, assign, nonatomic) BOOL stageProgressIndeterminate;
@property (readwrite, retain, nonatomic) ADBOperation *sourceFileImportOperation;
@property (readwrite, assign, nonatomic) BXSourceFileImportType sourceFileImportType;

//Only defined for internal use
@property (copy, nonatomic) NSURL *rootDriveURL;


//Create a new empty game package for our source path.
- (BOOL) _generateGameboxWithError: (NSError **)error;

//Return the path to which the current gamebox will be moved if renamed with the specified name.
- (NSURL *) _destinationURLForGameboxName: (NSString *)newName;

@end


#pragma mark -
#pragma mark Actual implementation

@implementation BXImportSession
@synthesize importWindowController = _importWindowController;
@synthesize sourceURL = _sourceURL;
@synthesize rootDriveURL = _rootDriveURL;
@synthesize installerURLs = _installerURLs;
@synthesize importStage = _importStage;
@synthesize stageProgress = _stageProgress;
@synthesize stageProgressIndeterminate = _stageProgressIndeterminate;
@synthesize sourceFileImportOperation = _sourceFileImportOperation;
@synthesize sourceFileImportType = _sourceFileImportType;
@synthesize sourceFileImportRequired = _sourceFileImportRequired;
@synthesize bundledConfigurationURL = _bundledConfigurationURL;
@synthesize configurationToImport = _configurationToImport;


#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
    self.importWindowController = nil;
    self.sourceURL = nil;
    self.rootDriveURL = nil;
    self.installerURLs = nil;
    self.sourceFileImportOperation = nil;
    self.bundledConfigurationURL = nil;
    self.configurationToImport = nil;
    
	[super dealloc];
}

- (id) initWithContentsOfURL: (NSURL *)absoluteURL
					  ofType: (NSString *)typeName
					   error: (NSError **)outError
{
	if ((self = [super initWithContentsOfURL: absoluteURL ofType: typeName error: outError]))
	{
		self.fileURL = self.sourceURL;
	}
	return self;
}


- (BOOL) readFromURL: (NSURL *)absoluteURL
			  ofType: (NSString *)typeName
			   error: (NSError **)outError
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert(absoluteURL != nil, @"No URL provided.");
	NSAssert(self.importStage <= BXImportSessionWaitingForInstaller, @"Cannot call readFromURL:ofType:error: after game import has already started.");
	
	_didMountSourceVolume = NO;
	
	NSURL *preferredURL = [self.class preferredSourceURLForURL: absoluteURL];
	if (!preferredURL)
    {
        return NO;
    }
    
    self.sourceURL = preferredURL;
    
    //Create an installer scan operation to perform the actual 'loading' of the URL
    //(scanning it for installer executables, game profile etc.)
    //The didFinish callback will continue the actual import process from this point.
    BXInstallerScan *scan = [BXInstallerScan scanWithBasePath: preferredURL.path];
    scan.delegate = self;
    scan.didFinishSelector = @selector(installerScanDidFinish:);
    
    //Don't automatically eject any image that the scan had to mount: instead
    //we'll use the mounted volume ourselves for later operations, and eject
    //it at the end of importing.
    scan.ejectAfterScanning = ADBFileScanNeverEject;
    
    [self.scanQueue addOperation: scan];
    self.importStage = BXImportSessionLoadingSource;
		
    return YES;
}

- (void) installerScanDidFinish: (NSNotification *)notification
{
    BXInstallerScan *scan = notification.object;
    
    if (scan.succeeded)
    {
        self.gameProfile = scan.detectedProfile;
        self.sourceURL = [NSURL fileURLWithPath: scan.recommendedSourcePath];
        //Record whether we ought to unmount any mounted volume after we're done.
        _didMountSourceVolume = scan.didMountVolume;
        
        //If the scan found DOSBox configuration files, choose one of these to guide the import process.
        if (scan.DOSBoxConfigurations.count)
        {
            NSArray *configurationURLs = [self.sourceURL URLsByAppendingPaths: scan.DOSBoxConfigurations];
            self.bundledConfigurationURL = [self.class preferredConfigurationFileFromURLs: configurationURLs];
        }
        
        self.fileURL = self.sourceURL;
        self.installerURLs = [self.sourceURL URLsByAppendingPaths: scan.matchingPaths];
        
        //If the scan found installers, and doesn't otherwise think
        //the game is already installed, then we'll ask the user to
        //choose which installer to use.
		if (!scan.isAlreadyInstalled && self.installerURLs.count)
        {
            #ifdef BOXER_DEBUG
			self.importStage = BXImportSessionWaitingForInstaller;
            [NSApp requestUserAttention: NSInformationalRequest];
			#else
			[self skipInstaller];
            #endif
        }
        //Otherwise, we'll get on with finalizing the import directly.
		else
        {
			[self skipInstaller];
        }
    }
    else
    {
        self.sourceURL = nil;
        self.installerURLs = nil;
        self.fileURL = nil;
		self.importStage = BXImportSessionWaitingForSource;
		
        //Eject any disk that was mounted as a result of the scan
        if (scan.didMountVolume)
        {
            NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
            [workspace unmountAndEjectDeviceAtPath: scan.mountedVolumePath];
            _didMountSourceVolume = NO;
        }
        
        //If there was an error that wasn't just that the operation was cancelled,
        //display it to the user now as an alert sheet.
        if (scan.error && !scan.error.isUserCancelledError)
        {
            [self presentError: scan.error
                modalForWindow: self.windowForSheet
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
    }
}


#pragma mark -
#pragma mark Window management

- (BOOL) isGameImport
{
    return YES;
}

- (void) makeWindowControllers
{
    BXDOSWindowController *controller;
	controller = [[BXDOSWindowControllerLion alloc] initWithWindowNibName: @"DOSImportWindow"];
	
	[self addWindowController: controller];
	self.DOSWindowController = controller;
	
	controller.shouldCloseDocument = YES;
    [controller release];
    
	
	BXImportWindowController *importController	= [[BXImportWindowController alloc] initWithWindowNibName: @"ImportWindow"];
	
	[self addWindowController: importController];
	self.importWindowController = importController;
	
	importController.shouldCloseDocument = YES;
	[importController release];
}

- (void) removeWindowController: (NSWindowController *)windowController
{
	if (windowController == self.importWindowController)
	{
		self.importWindowController = nil;
	}
	[super removeWindowController: windowController];
}

- (void) showWindows
{
	if (self.importStage == BXImportSessionRunningInstaller)
	{
		[self.DOSWindowController showWindow: self];
	}
	else
	{
		[self.importWindowController showWindow: self];
	}
}

- (NSWindow *) windowForSheet
{
	NSWindow *importWindow = self.importWindowController.window;

	if	(importWindow.isVisible) return importWindow;
	else return super.windowForSheet;
}


#pragma mark - Controlling shutdown

- (BOOL) canCloseSafely
{
    //If the gamebox is being imported and is not yet finalized, we can't close the document safely.
    if (self.gamebox != nil && self.importStage < BXImportSessionFinished)
        return NO;
    
    return YES;
}

//Overridden to display our own custom confirmation alert instead of the standard NSDocument one.
- (void) canCloseDocumentWithDelegate: (id)delegate
				  shouldCloseSelector: (SEL)shouldCloseSelector
						  contextInfo: (void *)contextInfo
{	
	//Define an invocation for the callback, which has the signature:
	//- (void)document:(NSDocument *)document shouldClose:(BOOL)shouldClose contextInfo:(void *)contextInfo;
	NSInvocation *callback = [NSInvocation invocationWithTarget: delegate selector: shouldCloseSelector];
	[callback setArgument: &self atIndex: 2];
	[callback setArgument: &contextInfo atIndex: 4];
	
	//If we have a gamebox and haven't finished finalizing it, show a stop importing/cancel prompt
	if (self.isDocumentEdited)
	{
        //If we're running an installer, ask the user if they want to quit the installer and finish importing,
        //or stop importing altogether. Otherwise, just ask if they want to stop importing. 
        BXCloseAlert *alert;
        if (self.importStage == BXImportSessionRunningInstaller)
            alert = [BXCloseAlert closeAlertWhileRunningInstaller: self];
        else
            alert = [BXCloseAlert closeAlertWhileImportingGame: self];
		
		//Show our custom close alert, passing it the callback so we can complete
		//our response down in _closeAlertDidEnd:returnCode:contextInfo:
		[alert beginSheetModalForWindow: self.windowForSheet
					  completionHandler: ^(NSModalResponse returnCode) {
						  [self _closeAlertDidEnd: alert returnCode: returnCode contextInfo: [callback retain]];
					  }];
	}
	else
	{
		//Otherwise we can respond directly: call the callback straight away with YES for shouldClose:
		BOOL shouldClose = YES;
		[callback setArgument: &shouldClose atIndex: 3];
		[callback invoke];
	}
}

- (void) _closeAlertDidEnd: (BXCloseAlert *)alert
				returnCode: (NSModalResponse)returnCode
			   contextInfo: (NSInvocation *)callback
{
	if (alert.showsSuppressionButton && alert.suppressionButton.state == NSControlStateValueOn)
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"suppressCloseAlert"];
	
    //Hide the alert before we go any further, so that it has time to get out of the way
    //before we animate the DOS window back to the import window's size.
    [alert.window orderOut: self];
    
	BOOL shouldClose = NO;
	
	//If the alert has three buttons it means it's a finish/don't finish confirmation
    //instead of a close/cancel confirmation.
	if (alert.buttons.count == 3)
	{
		switch (returnCode)
        {
			case NSAlertFirstButtonReturn:	//Finish importing
				[self finishInstaller];
				shouldClose = NO;
				break;
				
			case NSAlertSecondButtonReturn:	//Cancel
				shouldClose = NO;
				break;
				
			case NSAlertThirdButtonReturn:	//Stop importing
				shouldClose = YES;
				break;
		}
	}
	else
	{
		shouldClose = (returnCode == NSAlertFirstButtonReturn);
	}
	
	[callback setArgument: &shouldClose atIndex: 3];
	[callback invoke];
	
	//Release the previously-retained callback
	[callback release];	
}


#pragma mark -
#pragma mark Import helpers

+ (NSSet *)acceptedSourceTypes
{
	static NSSet *types = nil;
    
    //A subset of our usual mountable types: we only accept regular folders and disk image
    //formats which can be mounted by hdiutil (so that we can inspect their filesystems)
	if (!types) types = [[[BXFileTypes OSXMountableImageTypes] setByAddingObject: @"public.folder"] retain];
    
    return types;
}

+ (BOOL) canImportFromSourceURL: (NSURL *)URL
{
    return ([URL matchingFileType: self.acceptedSourceTypes] != nil);
}

- (BOOL) isRunningInstaller
{
    if ([self.launchedProgramURL isEqual: self.targetURL])              return YES;
	if ([self.installerURLs containsObject: self.launchedProgramURL])   return YES;
	if ([self.class isInstallerAtPath: self.launchedProgramURL.path])   return YES;
	
	return NO;
}


//Synthesized setter is overridden to reset the progress whenever we change the stage
- (void) setImportStage: (BXImportStage)stage
{
	if (stage != self.importStage)
	{
		_importStage = stage;
		self.stageProgress = 0.0f;
		self.stageProgressIndeterminate = YES;
	}
}


#pragma mark -
#pragma mark Gamebox renaming

- (NSURL *) _destinationURLForGameboxName: (NSString *)newName
{
	NSString *fullName = newName.lastPathComponent;
	if (![newName.pathExtension.lowercaseString isEqualToString: @"boxer"])
		fullName = [newName stringByAppendingPathExtension: @"boxer"];
	
	NSURL *currentURL = self.gamebox.bundleURL;
	NSURL *baseURL = [currentURL URLByDeletingLastPathComponent];
	NSURL *newURL = [baseURL URLByAppendingPathComponent: fullName];
	return newURL;
}

+ (NSSet *) keyPathsForValuesAffectingGameboxName { return [NSSet setWithObject: @"gamebox.gameName"]; }

- (NSString *) gameboxName
{
	return self.gamebox.gameName;
}

- (void) setGameboxName: (NSString *)newName
{
	NSString *originalName = self.gameboxName;
	if (self.gamebox && newName.length && ![newName isEqualToString: originalName])
	{
		NSURL *newGameboxURL = [self _destinationURLForGameboxName: newName];
		NSURL *currentGameboxURL = self.gamebox.bundleURL;
		
		NSFileManager *manager = [NSFileManager defaultManager];
		
		NSError *moveError;
		BOOL moved;
		
		//Special case: if the user is just changing the case of the filename, then a regular
		//move operation may cause a file-already-exists error on case-insensitive filesystems.
		//So we first rename the file to a temporary name, then back to the final name.
        //TODO: rewrite this to use NSFileManager's replaceItemAtURL: method.
		if ([newName.lowercaseString isEqualToString: originalName.lowercaseString])
		{
			NSURL *tempURL = [currentGameboxURL URLByAppendingPathExtension: @"-renaming"];
			
			moved = [manager moveItemAtURL: currentGameboxURL toURL: tempURL error: &moveError];
			if (moved)
			{
				moved = [manager moveItemAtURL: tempURL toURL: newGameboxURL error: &moveError];
				//If the second step of the rename failed, then put the file back to its original name
				if (!moved)
                    [manager moveItemAtURL: tempURL toURL: currentGameboxURL error: NULL];
			}
		}
		else
		{
			moved = [manager moveItemAtURL: currentGameboxURL toURL: newGameboxURL error: &moveError];
		}
		
		if (moved)
		{
			BXGamebox *movedGamebox = [BXGamebox bundleWithURL: newGameboxURL];
			self.gamebox = movedGamebox;
			
			if ([self.fileURL isEqual: currentGameboxURL])
				self.fileURL = newGameboxURL;
			
			//While we're at it, generate a new icon for the new gamebox name
			if (_hasAutoGeneratedIcon)
                [self generateBootlegIcon];
            
            //Also while we're at it, update the name of the default launcher to match the new name.
            NSMutableDictionary *launcherInfo = [self.gamebox.defaultLauncher mutableCopy];
            if (launcherInfo)
            {
                [launcherInfo setObject: newName forKey: BXLauncherTitleKey];
                [self.gamebox removeLauncherAtIndex: 0];
                [self.gamebox insertLauncher: launcherInfo atIndex: 0];
                [launcherInfo release];
            }
		}
		else
		{
			[self presentError: moveError
				modalForWindow: self.windowForSheet
					  delegate: nil
			didPresentSelector: nil
				   contextInfo: NULL];
		}
	}
}

//TODO: should we be handling this with NSFormatter validation instead?
- (BOOL) validateGameboxName: (id *)ioValue error: (NSError **)outError
{
	//Ensure the gamebox name only contains valid characters
	NSString *sanitisedName = [self.class validGameboxNameFromName: *ioValue];

	//If the string is now completely empty, treat it as an invalid filename
	if (!sanitisedName.length)
	{
		if (outError)
		{
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain
											code: NSFileWriteInvalidFileNameError
										userInfo: nil];
		}
		return NO;
	}
	
	//Check if a different gamebox already exists with the specified name at the intended destination
	//(Lowercase comparison avoids an error if the user is just changing the case of the original name)
	if (![sanitisedName.lowercaseString isEqualToString: self.gameboxName.lowercaseString])
	{
		NSURL *intendedURL = [self _destinationURLForGameboxName: sanitisedName];
		
		if ([intendedURL checkResourceIsReachableAndReturnError: NULL])
		{
			if (outError)
			{
				//Customise the error message to match Finder's behaviour
				NSString *messageFormat = NSLocalizedString(@"The name “%1$@” is already taken. Please choose another.",
															@"Error shown when user renames a gamebox to a name that already exists. %1$@ is the intended filename.");
				
                NSString *message = [NSString stringWithFormat: messageFormat, sanitisedName];
				NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: message, NSURLErrorKey: intendedURL };
                               
				*outError = [NSError errorWithDomain: NSCocoaErrorDomain
												code: NSFileWriteFileExistsError
											userInfo: userInfo];
			}
			return NO;
		}
	}
	
	//If the new sanitised name checked out, use that as the value and keep on going.
	*ioValue = sanitisedName;
	return YES;
}

- (void) setRepresentedIcon: (NSImage *)icon
{
	_hasAutoGeneratedIcon = NO;
	[super setRepresentedIcon: icon];
    
    [self.importWindowController synchronizeWindowTitleWithDocumentName];
}

- (void) generateBootlegIcon
{
	BXReleaseMedium medium = self.gameProfile.releaseMedium;
	
	//If the game profile doesn't have an era, then autodetect it
	if (medium == BXUnknownMedium)
	{
		//We prefer the original source path for autodetection,
		//but fall back on the contents of the gamebox if the source path has been removed.
		if ([self.sourceURL checkResourceIsReachableAndReturnError: NULL])
        {
            //TODO: check whether our source URL is original media (floppy disk, CD-ROM, ISO/IMG)
            //and if so match the era to the kind of media used.
			medium = [BXGameProfile mediumOfGameAtURL: self.sourceURL];
        }
		else if (self.gamebox)
        {
			medium = [BXGameProfile mediumOfGameAtURL: self.gamebox.bundleURL];
        }
		
		//Record the autodetected era so we don't have to scan the filesystem next time.
		self.gameProfile.releaseMedium = medium;
	}
	
	NSImage *icon = [self.class bootlegCoverArtForGamebox: self.gamebox
                                               withMedium: medium];
	
    self.representedIcon = icon;
	_hasAutoGeneratedIcon = YES;
}


#pragma mark -
#pragma mark Import steps

//IMPLEMENTATION NOTE: this is essentially a reimplementation of initWithContentsOfURL:fileType:withError:
//designed to be called programmatically after the document has been created, to 'fill in the gaps'.
//The actual work of this method is mostly done by readFromURL:ofType:error:, and this method just
//displays any error from that method.
//(This is going against the grain of how Cocoa documents are meant to work, and indicates that our
//'drop what you want to import here' stage of the import process should not be managed by a blank
//BXImportSession at all: but by a separate class that creates import sessions itself.)
- (void) importFromSourceURL: (NSURL *)URL
{
	NSError *readError = nil;
	BOOL readSucceeded = [self readFromURL: URL ofType: @"net.washboardabs.boxer-game-package" error: &readError];
    
    if (readSucceeded)
    {
		self.fileURL = self.sourceURL;
    }
    else
    {
		self.fileURL = nil;
		self.importStage = BXImportSessionWaitingForSource;
        
        if (readError)
        {
            //If we failed, then display the error as a sheet
            [self presentError: readError
                modalForWindow: self.windowForSheet
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
	}
}

- (void) cancelInstallerScan
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert(self.importStage <= BXImportSessionLoadingSource, @"Cannot call cancelInstallerScan after scan is finished.");
    
    [self.scanQueue cancelAllOperations];
    
    //Our installerScanDidFinish: callback will take care of resetting
    //the import state back to how it should be.
}

- (void) cancelSourceSelection
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert(self.importStage <= BXImportSessionWaitingForInstaller, @"Cannot call cancelSourcePath after game import has already started.");
    
	if (_didMountSourceVolume)
	{
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		[workspace unmountAndEjectDeviceAtURL: self.sourceURL error: NULL];
		_didMountSourceVolume = NO;
	}
	
	self.sourceURL = nil;
	self.fileURL = nil;
	self.importStage = BXImportSessionWaitingForSource;
}

- (void) launchInstallerAtURL: (NSURL *)URL
{
	//Sanity checks: if these fail then there is a programming error.
	NSAssert(URL != nil, @"No URL specified.");
	NSAssert(self.sourceURL != nil, @"No source URL for the import has been chosen.");
	
	//Generate a new gamebox for us to import into.
    NSError *generationError;
    BOOL createdGamebox = [self _generateGameboxWithError: &generationError];
    NSAssert(createdGamebox, @"Gamebox creation failed with error: %@", generationError);
	
	self.importStage = BXImportSessionRunningInstaller;
	
	self.importWindowController.shouldCloseDocument = NO;
	self.DOSWindowController.shouldCloseDocument = YES;
	[self.importWindowController handOffToController: self.DOSWindowController];
	
	//Set the installer as the target executable for this session
	self.targetURL = URL;
    
    //Aaaand start emulating!
	[self start];
}

- (void) skipInstaller
{
	self.targetURL = nil;
	self.importStage = BXImportSessionReadyToFinalize;
    
    //Create a new gamebox for us to import into.
    NSError *generationError;
    BOOL createdGamebox = [self _generateGameboxWithError: &generationError];
    
    NSAssert(createdGamebox, @"Gamebox creation failed with error: %@", generationError);
	
	[self importSourceFiles];
}

- (void) finishInstaller
{	
	//Stop the emulation process
	[self cancel];
	
	//Close the program panel before handoff, otherwise it scales weirdly
	[self.DOSWindowController hideProgramPanel: self];
	
	//Close the inspector panel also
	[BXInspectorController controller].visible = NO;
	
	//Hide the DOS view
    [self.DOSWindowController switchToPanel: BXDOSWindowLoadingPanel animate: YES];
	
	//Switch to the next stage before handing off, so that the correct panel is visible as soon as we do
	self.importStage = BXImportSessionReadyToFinalize;
	
	//Finally, hand off to the import window
	[self.importWindowController pickUpFromController: self.DOSWindowController];
	
	//Aaaaand start in on the next stage immediately
	[self importSourceFiles];
}


#pragma mark -
#pragma mark Finalizing the import


//FIXME: this is a massive function, and a lot of its work could be split up.
- (void) importSourceFiles
{
	//Sanity checks: if these fail then there is a programming error.
	//The fact that we're even checking this shit is proof that this class needs refactoring big-time
	NSAssert(self.importStage == BXImportSessionReadyToFinalize, @"BXImportSession importSourceFiles: was called before we are ready to finalize.");
	NSAssert(self.sourceURL != nil, @"No source URL for the import has been chosen.");
	
    
    //Before we begin, wait for any already-in-progress operations to finish
	//(In case the user started importing volumes via the Drives panel during installation)
	[self.importQueue waitUntilAllOperationsAreFinished];
	
    
	NSFileManager *manager = [NSFileManager defaultManager];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSSet *bundleableTypes = [[BXFileTypes mountableFolderTypes] setByAddingObjectsFromSet: [BXFileTypes mountableImageTypes]];
    
	
	//Determine how we should import the source files
	//-----------------------------------------------
    
	//If the source path no longer exists, it means the user probably
    //ejected the disk and we can't import it.
	//FIXME: make this properly handle the case where the source path
    //was a mounted volume for a disc image, and the user just unmounted the volume.
    //This will require us tracking the 'source for the source'.
	if (![self.sourceURL checkResourceIsReachableAndReturnError: NULL])
	{
		//Skip straight to cleanup
		[self finalizeGamebox];
		return;
	}
	
	//If there are already drives in the gamebox other than C,
    //it means the user did their own importing and we shouldn't
    //interfere with their work.
	NSArray *alreadyBundledVolumes = [self.gamebox URLsOfVolumesMatchingTypes: bundleableTypes];
	if (alreadyBundledVolumes.count > 1) //There will always be a volume for the C drive
	{
		//Skip straight to cleanup
		[self finalizeGamebox];
		return;
	}
	
	
	//At this point, all the edge cases are out of the way
    //and we know we'll need to import something.
	//Now we need to decide exactly what we're importing,
    //and how we should import it.
    ADBOperation *importOperation = nil;
	BXSourceFileImportType importType = BXImportTypeUnknown;
    BOOL didInstallFiles = self.gameDidInstall;
    
    //If we have a configuration file to work from, check it to see if it defines any drives.
    //If so, we'll import those drives directly.
    if (self.bundledConfigurationURL)
        self.configurationToImport = [BXEmulatorConfiguration configurationWithContentsOfURL: self.bundledConfigurationURL
                                                                                       error: NULL];
    
    if (self.configurationToImport && (!self.gameProfile || self.gameProfile.shouldImportMountCommands))
    {
        NSArray *mountCommands = [self.class mountCommandsFromConfiguration: self.configurationToImport];
        if (mountCommands.count)
        {
            NSURL *baseURL = self.bundledConfigurationURL.URLByDeletingLastPathComponent;
            
            ADBFileTransferSet *driveImportSet = [[[ADBFileTransferSet alloc] init] autorelease];
            driveImportSet.copyFiles = YES;
            
            for (NSString *mountCommand in mountCommands)
            {
                BXDrive *driveToImport = [BXEmulator driveFromMountCommand: mountCommand
                                                             relativeToURL: baseURL
                                                                     error: NULL];
                
                ADBOperation <BXDriveImport> *driveImport = [self importOperationForDrive: driveToImport
                                                                         startImmediately: NO];
                
                if (driveImport)
                {
                    driveImport.delegate = nil;
                    
                    [driveImportSet.operations addObject: driveImport];
                    
                    //If a drive C was defined, then remove our gamebox's own drive C.
                    //FIXME: work out how to make this non-destructive if didInstallFiles is YES,
                    //i.e. if we ran an installer first that put its own files on drive C.
                    //(Currently this will never be the case, because the presence of a
                    //configuration file will stop the importer from offering to run an installer.)
                    if ([driveToImport.letter isEqualToString: @"C"])
                    {
                        [manager removeItemAtURL: self.rootDriveURL error: nil];
                        self.rootDriveURL = driveImport.destinationURL;
                    }
                }
                //If we couldn't determine how to import this drive, flag it up as a failure.
                else
                {
                    if (![driveToImport.sourceURL checkResourceIsReachableAndReturnError: NULL])
                    {
                        NSError *driveError = [BXImportDriveUnavailableError errorWithSourceURL: self.sourceURL
                                                                                          drive: driveToImport
                                                                                       userInfo: nil];
                        
                        [self presentError: driveError
                            modalForWindow: self.windowForSheet
                                  delegate: nil
                        didPresentSelector: NULL
                               contextInfo: NULL];
                        
                        //Bail out altogether.
                        //TODO: throw this up to an upstream context.
                        
                        [manager removeItemAtURL: self.gamebox.bundleURL error: NULL];
                        self.sourceURL = nil;
                        self.fileURL = nil;
                        self.installerURLs = nil;
                        self.gamebox = nil;
                        self.importStage = BXImportSessionWaitingForSource;
                        return;
                    }
                }
            }
            
            //Once all operations have been defined, run through them looking for nested drives:
            //i.e. drives that are located within the file structure of another drive import operation.
            for (ADBOperation <BXDriveImport> *driveImport in driveImportSet.operations)
            {
                for (ADBOperation <BXDriveImport> *otherDriveImport in driveImportSet.operations)
                {
                    if (driveImport == otherDriveImport) continue;
                    
                    NSURL *driveURL1 = driveImport.drive.sourceURL, *driveURL2 = otherDriveImport.drive.sourceURL;
                    
                    if (![driveURL1 isEqual: driveURL2] && [driveURL1 isBasedInURL: driveURL2])
                    {
                        //Make the import for the nested drive dependent on the import for the containing drive,
                        //so that it won't start until the other drive has been copied.
                        [driveImport addDependency: otherDriveImport];
                        
                        //Change the source path for the nested drive to point to where the drive will
                        //have ended up after the containing drive has been copied.
                        NSString *relativeSourcePath = [driveURL1 pathRelativeToURL: driveURL2];
                        NSURL *driveDestination = otherDriveImport.preferredDestinationURL;
                        NSURL *intermediateSourceURL = [driveDestination URLByAppendingPathComponent: relativeSourcePath];
                        
                        driveImport.drive.sourceURL = intermediateSourceURL;
                        
                        //Make the nested drive import into a move operation instead,
                        //since the drive's files will have been copied along with the containing drive.
                        [driveImport setCopyFiles: NO];
                    }
                }
            }
            
            if (driveImportSet.operations.count)
            {
                importOperation = driveImportSet;
                importType = BXImportFromPreInstalledGame;
            }
        }
    }
    
    //If no configuration file was available to guide importing,
    //scan the source path itself to see how best to import it.
    if (!importOperation)
    {
        BXDrive *driveToImport = nil;
        
        BOOL isMountableImage = [self.sourceURL matchingFileType: [BXFileTypes mountableImageTypes]] != nil;
        BOOL isMountableFolder = !isMountableImage && [self.sourceURL matchingFileType: [BXFileTypes mountableFolderTypes]] != nil;
        
        //If the source path is directly bundleable (it is an image or a mountable folder)
        //then import it as a new drive into the gamebox.
        if (isMountableImage || isMountableFolder)
        {
            driveToImport = [BXDrive driveWithContentsOfURL: self.sourceURL letter: nil type: BXDriveAutodetect];
            
            //If the drive is marked as being for drive C, then check what we need to do with our original C drive
            if ([driveToImport.letter isEqualToString: @"C"])
            {
                //If any files were installed to the original C drive, then reset the import drive letter
                //so that the drive will be imported alongside the existing C drive.
                if (didInstallFiles)
                {
                    driveToImport.letter = nil;
                }
                //Otherwise, delete the original empty C drive so we can replace it with this one
                else
                {
                    [manager removeItemAtURL: self.rootDriveURL error: nil];
                }
            }
            
            //Mark what kind of import we're doing based on what the autodetected drive type is
            switch (driveToImport.type)
            {
                case BXDriveCDROM:
                    importType = (isMountableImage) ? BXImportFromCDImage : BXImportFromFolderToCD; break;
                case BXDriveFloppyDisk:
                    importType = (isMountableImage) ? BXImportFromFloppyImage : BXImportFromFolderToFloppy; break;
                default:
                    importType = (isMountableImage) ? BXImportFromHardDiskImage : BXImportFromFolderToHardDisk; break;
            }
            importOperation = [self importOperationForDrive: driveToImport startImmediately: NO];
        }
        
        //Otherwise, we need to decide if the source path represents an already-installed
        //game folder (which should be imported directly to the C drive) or whether it
        //represents the original install media (which should be imported as a separate
        //CD-ROM/floppy disk.)
        else
        {
            NSURL *volumeURL = nil;
            [self.sourceURL getResourceValue: &volumeURL forKey: NSURLVolumeURLKey error: NULL];
            NSString *volumeType = [workspace typeOfVolumeAtURL: volumeURL];
            
            BOOL isRealCDROM = [volumeType isEqualToString: ADBDataCDVolumeType];
            BOOL isRealFloppy = !isRealCDROM && [workspace isFloppyVolumeAtURL: volumeURL];
            
            //If the installer copied files to our C drive, or the source files are on
            //a CDROM/floppy volume, then the source files presumably represent the original
            //install media and should be imported as a new CD-ROM/floppy disk.
            if (didInstallFiles || isRealCDROM || isRealFloppy)
            {
                NSURL *URLToImport = self.sourceURL;
                NSURL *sourceImageURL = [workspace sourceImageForVolumeAtURL: self.sourceURL];
                BOOL isDiskImage = NO;
            
                //If the source path is on a DOSBox-compatible disk image, then import the image directly.
                if (sourceImageURL && [sourceImageURL matchingFileType: [BXFileTypes mountableImageTypes]] != nil)
                {
                    isDiskImage = YES;
                    URLToImport = sourceImageURL;
                }
                
                //If the source is an actual floppy disk, or this game expects to be installed off floppies,
                //then import the source files as a floppy disk.
                if (isRealFloppy || self.gameProfile.sourceDriveType == BXDriveFloppyDisk)
                {
                    if (isDiskImage)		importType = BXImportFromFloppyImage;
                    else if (isRealFloppy)	importType = BXImportFromFloppyVolume;
                    else					importType = BXImportFromFolderToFloppy;
                    
                    driveToImport = [BXDrive driveWithContentsOfURL: URLToImport letter: @"A" type: BXDriveFloppyDisk];
                }
                //In all other cases, import the source files as a CD-ROM drive.
                else
                {
                    if (isDiskImage)		importType = BXImportFromCDImage;
                    else if (isRealCDROM)	importType = BXImportFromCDVolume;
                    else					importType = BXImportFromFolderToCD;
                
                    driveToImport = [BXDrive driveWithContentsOfURL: URLToImport letter: @"D" type: BXDriveCDROM];
                }
                
                importOperation = [self importOperationForDrive: driveToImport startImmediately: NO];
            }
            
            //If the game didn't install anything and we're not importing a CD or floppy disk,
            //then assume that the source files represent an already-installed game, and copy
            //the source files directly into the gamebox's C drive.
            else
            {
                importType = BXImportFromPreInstalledGame;
                
                //Guess whether the game files expect to be located in the root of drive C
                //(GOG games, Steam games etc.) or in a subfolder within drive C
                //(almost everything else)
                BOOL needsSubfolder = [self.class shouldUseSubfolderForSourceFilesAtURL: self.sourceURL];
                NSString *subfolderPath	= self.gameProfile.preferredInstallationFolderPath;
                
                if (needsSubfolder && ![subfolderPath isEqualToString: @""])
                {
                    //If the game profile didn't suggest a specific path then
                    //just use a sanitised version of the source directory name.
                    if (!subfolderPath)
                    {
                        //Ensure the destination name will be DOSBox-compatible
                        subfolderPath = [self.class validDOSNameFromName: self.sourceURL.lastPathComponent];
                    }
                    
                    NSURL *destinationURL = [self.rootDriveURL URLByAppendingPathComponent: subfolderPath];
                    
                    //If we need to copy the source path into a subfolder of drive C,
                    //then do this as a regular file copy rather than a drive import.
                    importOperation = [ADBSingleFileTransfer transferFromPath: self.sourceURL.path
                                                                       toPath: destinationURL.path
                                                                    copyFiles: YES];
                }
                else
                {
                    //Otherwise, remove the old empty C drive we created and import
                    //the source path as a new C drive in its place.
                    [manager removeItemAtURL: self.rootDriveURL error: nil];
                    driveToImport = [BXDrive driveWithContentsOfURL: self.sourceURL letter: @"C" type: BXDriveHardDisk];
                    //Don't bother with a volume label for drive C.
                    driveToImport.volumeLabel = nil;
                    importOperation	= [self importOperationForDrive: driveToImport startImmediately: NO];
                }
            }
        }
	}
    
	//Set up the import operation and start it running.
	self.sourceFileImportType = importType;
	self.sourceFileImportOperation = importOperation;
    
	//If the gamebox is empty, then we need to import the source files for it to work at all;
	//so make cancelling the drive import cancel the rest of the import as well.
	self.sourceFileImportRequired = !didInstallFiles;
	self.importStage = BXImportSessionImportingSourceFiles;
	
	[self.importQueue addOperation: importOperation];
}

- (BOOL) sourceFileImportRequired
{
	//We require source files to be imported in all cases except when importing from physical CD.
	//This is because that's the only situation that doesn't suck to recover from, if it turns
	//out the game needs the CD (because you can just keep it in the drive and Boxer's happy.)
	//TODO: make this decision more formal and/or move it upstairs into importSourceFiles.
	return _sourceFileImportRequired || (self.sourceFileImportType != BXImportFromCDVolume);
}

- (void) cancelSourceFileImport
{
	NSOperation *operation = self.sourceFileImportOperation;
	
	if (operation && !operation.isFinished && self.importStage == BXImportSessionImportingSourceFiles)
	{
		[operation cancel];
		self.importStage = BXImportSessionCancellingSourceFileImport;
	}
}


#pragma mark BXOperation delegate methods

- (void) setSourceFileImportOperation: (ADBOperation *)operation
{
	if (operation != self.sourceFileImportOperation)
	{
		[_sourceFileImportOperation release];
        _sourceFileImportOperation = [operation retain];
		
		//Set up our source file import operation with custom callbacks
		if (operation)
		{
			operation.delegate = self;
			operation.inProgressSelector = @selector(sourceFileImportInProgress:);
			operation.didFinishSelector = @selector(sourceFileImportDidFinish:);
		}
	}
}

- (void) sourceFileImportInProgress: (NSNotification *)notification
{
	ADBOperation *operation = notification.object;
    
	//Update our own progress to match the operation's progress
	self.stageProgressIndeterminate = operation.isIndeterminate;
	self.stageProgress = operation.currentProgress;
}

- (void) sourceFileImportDidFinish: (NSNotification *)notification
{
	ADBOperation *operation = notification.object;
	
	//Some source-file copies can be simple file transfers
	BOOL isImport = [operation conformsToProtocol: @protocol(BXDriveImport)];
	
	//If the operation succeeded or was cancelled by the user,
	//then proceed with the next stage of the import (cleanup.)
	if (operation.succeeded || operation.isCancelled)
	{
		if (!operation.isCancelled)
		{
            //If the imported drive is replacing our original C drive, then
            //update the root drive path accordingly so that cleanGamebox
            //will clean up the right place.
            if (isImport && [((id <BXDriveImport>)operation).drive.letter isEqualToString: @"C"])
            {
                self.rootDriveURL = ((id <BXDriveImport>)operation).destinationURL;
            }
        }
		
		self.sourceFileImportOperation = nil;
		[self finalizeGamebox];
	}
	
	//If the operation failed with an error, then determine if we can retry
	//with a safer import method, or skip to the next stage if not.
	else
	{
		ADBOperation <BXDriveImport> *fallbackImport = nil;
		
		//Check if we can retry the operation...
		if (isImport && (fallbackImport = [BXDriveImport fallbackForFailedImport: (id <BXDriveImport>)operation]) != nil)
		{
			self.sourceFileImportOperation = fallbackImport;
			
			//IMPLEMENTATION NOTE: we add a short delay before retrying from BIN/CUE imports,
			//to allow time for the original volume to remount fully.
			if ([operation isKindOfClass: [BXBinCueImageImport class]])
			{
				[self.importQueue performSelector: @selector(addOperation:) withObject: fallbackImport afterDelay: 2.0];
			}
			else [self.importQueue addOperation: fallbackImport];
		}
		
		//..and if not, skip the import altogether and pretend everything's OK.
		//TODO: analyze whether this failure will have resulted in an unusable gamebox,
		//then warn the user and offer to try importing again.
		else
		{
			self.sourceFileImportOperation = nil;
			[self finalizeGamebox];
		}
	}
}

- (void) finalizeGamebox
{
	self.importStage = BXImportSessionCleaningGamebox;
	
    //Import any bundled DOSBox configuration: converting any launch commands into a launcher batch file.
    if (self.configurationToImport)
    {   
        if (!self.gameProfile || self.gameProfile.shouldImportLaunchCommands)
        {
            //If the original autoexec contained any launch commands, convert those
            //into a launcher batchfile in the root drive: we then assign that as
            //the default program to launch.
            NSArray *launchCommands = [self.class launchCommandsFromConfiguration: self.configurationToImport];
            
            if (launchCommands.count)
            {
                //Add an echo-off to the top of the launch commands if there isn't one already there.
                if (![[launchCommands objectAtIndex: 0] hasPrefix: @"@echo off"])
                {
                    launchCommands = [[launchCommands mutableCopy] autorelease];
                    [(NSMutableArray *)launchCommands insertObject: @"@echo off" atIndex: 0];
                }
                
                NSURL *launcherURL = [self.rootDriveURL URLByAppendingPathComponent: @"bxlaunch.bat"];
                NSString *startupCommandString = [launchCommands componentsJoinedByString: @"\r\n"];
                
                BOOL createdLauncher = [startupCommandString writeToURL: launcherURL
                                                             atomically: NO
                                                               encoding: BXDisplayStringEncoding
                                                                  error: nil];
                
                if (createdLauncher)
                {
                    [self.gamebox addLauncherWithURL: launcherURL
                                           arguments: nil
                                               title: self.gameboxName];
                }
            }
        }
        
        if (!self.gameProfile || self.gameProfile.shouldImportSettings)
        {
            //Strip out all the junk we don't care about from the original game configuration.
            BXEmulatorConfiguration *sanitizedConfig = [self.class sanitizedVersionOfConfiguration: self.configurationToImport];
            
            //Save the sanitized configuration into our new gamebox.
            [self _saveGameboxConfiguration: sanitizedConfig];
        }
    }
    
    
    //After picking up any bundled configuration, scan the imported root drive
    //to strip out unnecessary files and to migrate any remaining disc images.
	NSFileManager *manager	= [NSFileManager defaultManager];
    
	NSURL *URLToClean = self.rootDriveURL;
	NSSet *bundleableTypes = [[BXFileTypes mountableFolderTypes] setByAddingObjectsFromSet: [BXFileTypes mountableImageTypes]];
	NSDirectoryEnumerator *enumerator = [manager enumeratorAtURL: URLToClean
                                      includingPropertiesForKeys: nil
                                                         options: 0
                                                    errorHandler: NULL];
	
	for (NSURL *URL in enumerator)
	{
		//Grab the relative path to use for heuristic filename-pattern checks,
		//so that the base folder doesn't get involved in the heuristic.
		NSString *relativePath = [URL pathRelativeToURL: URLToClean];
		if ([self.class isJunkFileAtPath: relativePath])
		{
			[manager removeItemAtURL: URL error: NULL];
			continue;
		}
		
		BOOL isBundleable = ([URL matchingFileType: bundleableTypes] != nil);
        
        //TWEAK: exclude .img images from the bundleable types, because it is much more
        //likely that these are regular resource files for a DOS game, not actual images.
        //TODO: validate whether each found image is actually a proper image, regardless
        //of file extension.
        if (isBundleable && [URL.pathExtension.lowercaseString isEqualToString: @"img"])
            isBundleable = NO;
        
        //If this file is a mountable type, move it into the gamebox's root folder where we can find it.
		if (isBundleable)
		{
			BXDrive *drive = [BXDrive driveWithContentsOfURL: URL letter: nil type: BXDriveAutodetect];
			
			ADBOperation <BXDriveImport> *importOperation = [BXDriveImport importOperationForDrive: drive
                                                                              destinationFolderURL: self.gamebox.resourceURL
                                                                                         copyFiles: NO];
			
			//Note: we don't set ourselves as a delegate for this import operation
			//because we don't care about success or failure notifications.
			[self.importQueue addOperation: importOperation];
		}
	}
	
	//Any import operations we do in this stage would be moves within the same volume,
	//so they should be done already, but let's wait anyway.
	[self.importQueue waitUntilAllOperationsAreFinished];
	
	//That's all folks!
	self.importStage = BXImportSessionFinished;
	
	//Add to the recent documents list
	[[NSDocumentController sharedDocumentController] noteNewRecentDocument: self];
	
	//If we're not focused, let the user know via a notification that we're done
    if (![NSApp isActive] && [ADBUserNotificationDispatcher userNotificationsAvailable])
	{
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        
        notification.title = self.displayName;
        notification.subtitle = NSLocalizedString(@"Game imported successfully", @"Subtitle of user notification shown when a game finishes importing.");
        
        [[ADBUserNotificationDispatcher dispatcher] scheduleNotification: notification
                                                                  ofType: BXGameImportedNotificationType
                                                              fromSender: self
                                                            onActivation: ^(NSUserNotification *deliveredNotification) {
                                                                [self showWindows];
                                                                [[ADBUserNotificationDispatcher dispatcher] removeNotification: deliveredNotification];
                                                            }];
        
        [notification release];
    }
    //Otherwise, just bounce the dock icon to notify the user that we're done
    else
    {
        [NSApp requestUserAttention: NSInformationalRequest];
    }
}


#pragma mark - Responses to BXEmulator events

//Overridden so that the 'program panel' (i.e. installation tips panel) will always be shown when starting a program.
- (void) emulatorWillStartProgram: (NSNotification *)notification
{
    //If we've finished the startup process, then show the DOS view at this point.
    if (_hasLaunched)
    {
        [self.DOSWindowController showDOSView];
		[self.DOSWindowController performSelector: @selector(showProgramPanel:)
                                       withObject: self
                                       afterDelay: 1.0];
    }
    
	//Don't set the active program if we already have one: this way, we keep
	//track of which program the user manually launched, and won't glom onto
    //other programs spawned by the original program (e.g. if it was a batch file.)
	if (!self.launchedProgramURL)
	{
		NSURL *programURL = [notification.userInfo objectForKey: BXEmulatorLogicalURLKey];
        
        if (programURL)
        {
            NSString *arguments = [notification.userInfo objectForKey: BXEmulatorLaunchArgumentsKey];
            self.launchedProgramURL = programURL;
            self.launchedProgramArguments = arguments;
		}
	}
    
    //Enable/disable display-sleep suppression
    [self _syncSuppressesDisplaySleep];
}

//Overridden to always drop out of fullscreen mode after quitting a program,
//since the user needs to see the options to finish importing.
- (void) emulatorDidReturnToShell: (NSNotification *)notification
{
	//Clear the active program
    self.launchedProgramURL = nil;
    self.launchedProgramArguments = nil;
	
	//Show the program chooser after returning to the DOS prompt
	//(Show only after a delay, so that the window has time to resize after quitting the game)
	[self.DOSWindowController performSelector: @selector(showProgramPanel:)
                                   withObject: self
                                   afterDelay: 1.0];
	
	//Always drop out of fullscreen mode when we return to the prompt,
	//so that users can see the "finish importing" option
	[self.DOSWindowController exitFullScreen];
}

- (void) emulatorDidFinish: (NSNotification *)notification
{
	[super emulatorDidFinish: notification];
	
	//Once the emulation session finishes, finalize the import.
    //IMPLEMENTATION NOTE: isCancelled will be NO if the user quit by typing "exit" at
    //the command prompt, in which case we just assume they wanted to finish.
    //If the user closed the window, isCancelled will be YES, and we will already have
    //decided upstairs in the close confirmation whether to continue importing or not.
	if (!self.emulator.isCancelled && self.importStage == BXImportSessionRunningInstaller)
	{
		[self finishInstaller];
	}
}


#pragma mark -
#pragma mark Private internal methods

- (BOOL) _shouldPersistGameProfile: (BXGameProfile *)profile
{
    //Not all of the game's files may be available for comparison during importing,
    //potentially causing game detection heuristics to fail: so only persist the game
    //profile if we've already got a positive match on a particular game.
    return profile && ![profile.identifier isEqualToString: BXGenericProfileIdentifier];
}

- (BOOL) _shouldPersistQueuedDrives
{
    //The state of the drives during import is no indication of how they should be once
    //importing is completed.
    return NO;
}

- (BOOL) _shouldSuppressDisplaySleep
{
    //Always allow the display to go to sleep when it wants, on the assumption that
    //the emulation isn't doing anything particularly interesting during installation.
    return NO;
}

- (BOOL) _shouldAutoPause
{
	//Don't auto-pause the emulation while an installer is running, even if the
    //autopause-in-background preference is on: this allows lengthy copy operations
    //to continue in the background.
    if (!self.emulator.isAtPrompt) return NO;
    
    else return [super _shouldAutoPause];
}

//We don't want to close the entire document after the emulated session is finished;
//instead we carry on and complete the installation process.
- (BOOL) _shouldCloseOnEmulatorExit { return NO; }

//We also don't want to start emulating as soon as the import session is created.
- (BOOL) _shouldStartImmediately { return NO; }

//And we DEFINITELY don't want to close when returning to the DOS prompt in any case.
- (BOOL) _shouldCloseOnProgramExit	{ return NO; }

//Don't shadow any drives during importing, otherwise we'll never actually install stuff into the gamebox.
- (BOOL) _shouldShadowDrive: (BXDrive *)drive
{
    return NO;
}

//This uses a different (and simpler) mount behaviour than BXSession to prioritise
//the source path ahead of other drives.
- (void) _mountDrivesForSession
{
	//Determine what type of media this game expects to be installed from,
	//and how much free space to allow for it
	BXDriveType sourceDriveType = BXDriveAutodetect;
	NSInteger freeSpace = BXDefaultFreeSpace;
    
	if (self.gameProfile)
	{
        sourceDriveType = self.gameProfile.sourceDriveType;
		freeSpace = self.gameProfile.requiredDiskSpace;
    }
    
	if (sourceDriveType == BXDriveAutodetect)
		sourceDriveType = [BXDrive preferredTypeForContentsOfURL: self.sourceURL];
	
	if (freeSpace == BXDefaultFreeSpace && (sourceDriveType == BXDriveCDROM || [self.class isCDROMSizedGameAtURL: self.sourceURL]))
		freeSpace = BXFreeSpaceForCDROMInstall;
	
	
	//Mount our newly-minted empty gamebox as drive C.
    NSError *mountError = nil;
	BXDrive *destinationDrive = [BXDrive driveWithContentsOfURL: self.rootDriveURL letter: @"C" type: BXDriveHardDisk];
    destinationDrive.title = NSLocalizedString(@"Destination Drive",
                                               @"The display title for the gamebox’s C drive when importing a game.");
	destinationDrive.freeSpace = freeSpace;
    
	[self mountDrive: destinationDrive
            ifExists: BXDriveReplace
             options: BXBundledDriveMountOptions
               error: &mountError];
	
	//Then, create a drive of the appropriate type from the source files and mount away
	BXDrive *sourceDrive = [BXDrive driveWithContentsOfURL: self.sourceURL letter: nil type: sourceDriveType];
	[sourceDrive setTitle: NSLocalizedString(@"Source Drive", @"The display title for the source drive when importing.")];
    
    [self mountDrive: sourceDrive
            ifExists: BXDriveReplace
             options: BXImportSourceMountOptions
               error: &mountError];
	
	//Automount all currently mounted floppy and CD-ROM volumes
	[self mountFloppyVolumesWithError: &mountError];
	[self mountCDVolumesWithError: &mountError];
	
	//Mount our internal DOS toolkit and temporary drives unless the profile says otherwise
	if (!self.gameProfile || self.gameProfile.shouldMountHelperDrivesDuringImport)
	{
		[self mountToolkitDriveWithError: &mountError];
        
        if (!self.gameProfile || self.gameProfile.shouldMountTempDrive)
            [self mountTempDriveWithError: &mountError];
	}
}

- (BOOL) _generateGameboxWithError: (NSError **)outError
{	
	NSAssert(self.sourceURL != nil, @"_generateGameboxWithError: called before source URL was set.");

	NSFileManager *manager = [NSFileManager defaultManager];

	NSString *gameName		= [self.class validGameboxNameFromName: self.gameProfile.gameName];
	if (!gameName) gameName	= [self.class gameboxNameForGameAtURL: self.sourceURL];
	
    
    NSURL *gamesFolder = [(BXAppController *)[NSApp delegate] gamesFolderURL];
	//If the games folder is missing or not set, then fall back on a path we know does exist (the Desktop)
    if (![gamesFolder checkResourceIsReachableAndReturnError: NULL])
        gamesFolder = [(BXAppController *)[NSApp delegate] fallbackGamesFolderURL];
	
    NSString *fullGameName = [gameName stringByAppendingPathExtension: @"boxer"];
	NSURL *baseGameboxURL = [gamesFolder URLByAppendingPathComponent: fullGameName];
	
    //Create a uniquely named URL
    NSURL *gameboxURL = [manager createDirectoryAtURL: baseGameboxURL
                                       filenameFormat: ADBDefaultIncrementedFilenameFormat
                                           attributes: @{ NSFileExtensionHidden: @(YES) }
                                                error: outError];
    
    if (!gameboxURL)
        return NO;
    
    BXGamebox *gamebox = [BXGamebox bundleWithURL: gameboxURL];
	if (gamebox)
	{
		//Prep the gamebox by creating an empty C drive in it
		NSURL *rootDriveURL = [gamebox.resourceURL URLByAppendingPathComponent: @"C.harddisk"];
		
		BOOL createdRootDrive = [manager createDirectoryAtURL: rootDriveURL
                                  withIntermediateDirectories: NO
                                                   attributes: nil
                                                        error: outError];
		
		if (createdRootDrive)
		{
            //Assign this as the gamebox for this session
			self.gamebox = gamebox;
			self.fileURL = gamebox.bundleURL;
			self.rootDriveURL = rootDriveURL;
            
            //Try to find a suitable cover-art icon from the source path
            NSImage *icon = [self.class boxArtForGameAtURL: self.sourceURL];
            if (icon)
            {
                self.representedIcon = icon;
            }
            else
            {
                [self generateBootlegIcon];
            }
            
			return YES;
		}
		//If the C-drive creation failed for some reason, bail out and delete the new gamebox
		else
		{
			[manager removeItemAtURL: gamebox.bundleURL error: NULL];
			return NO;
		}
	}
	else
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileReadNoSuchFileError
                                        userInfo: @{ NSURLErrorKey: gameboxURL }];
        }
        return NO;
    }
}


- (BOOL) gameDidInstall
{
	if (!self.rootDriveURL) return NO;
	
	//Check if any files were copied to the root drive
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: self.rootDriveURL
                                                             includingPropertiesForKeys: @[NSURLIsRegularFileKey]
                                                                                options: NSDirectoryEnumerationSkipsHiddenFiles
                                                                           errorHandler: NULL];
	
    for (NSURL *URL in enumerator)
	{
        NSNumber *isFileFlag = nil;
        BOOL checkedFile = [URL getResourceValue: &isFileFlag forKey: NSURLIsRegularFileKey error: NULL];
        
		//If any actual files (not empty directories) were created, then assume the game installed.
		//IMPLEMENTATION NOTE: We'd like to be more rigorous and check for executables, but some
        //CD-ROM games only store configuration files on the hard drive.
        if (checkedFile && isFileFlag.boolValue)
            return YES;
	}
	return NO;
}


- (void) _cleanup
{
	[super _cleanup];
	
	//Delete our newly-minted gamebox if we didn't finish importing it before we were closed
	if (self.importStage != BXImportSessionFinished && self.gamebox)
	{
		NSString *path = self.gamebox.bundlePath;
		if (path)
		{
			NSFileManager *manager = [NSFileManager defaultManager];
			[manager removeItemAtPath: path error: NULL];	
		}
	}
	
	//Unmount any source volume that we mounted in the course of importing
	if (_didMountSourceVolume)
	{
		NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
		[workspace unmountAndEjectDeviceAtURL: self.sourceURL error: NULL];
		_didMountSourceVolume = NO;
	}
}

@end
