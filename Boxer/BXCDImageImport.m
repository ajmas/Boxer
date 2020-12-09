/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXCDImageImport.h"
#import "ADBFileTransfer.h"
#import "NSWorkspace+ADBMountedVolumes.h"
#import "BXDrive.h"
#import "RegexKitLite.h"
#import "NSFileManager+ADBUniqueFilenames.h"


NSString * const BXCDImageImportErrorDomain = @"BXCDImageImportErrorDomain";


#pragma mark -
#pragma mark Implementations

@implementation BXCDImageImport
@synthesize currentProgress = _currentProgress;
@synthesize indeterminate = _indeterminate;

@synthesize drive = _drive;
@synthesize destinationFolderURL	= _destinationFolderURL;
@synthesize destinationURL          = _destinationURL;


#pragma mark -
#pragma mark Helper class methods

+ (BOOL) driveUnavailableDuringImport
{
    return NO;
}

+ (BOOL) isSuitableForDrive: (BXDrive *)drive
{
    NSDictionary *volumeAttrs = [drive.sourceURL resourceValuesForKeys: @[NSURLIsVolumeKey, NSURLVolumeURLKey]
                                                                 error: NULL];
	
    if (![[volumeAttrs objectForKey: NSURLIsVolumeKey] boolValue])
        return NO;
    
    NSURL *volumeURL = [volumeAttrs objectForKey: NSURLVolumeURLKey];
    NSString *volumeType = [[NSWorkspace sharedWorkspace] typeOfVolumeAtURL: volumeURL];
    return [volumeType isEqualToString: ADBDataCDVolumeType];
}

+ (NSString *) nameForDrive: (BXDrive *)drive
{
	NSString *baseName = [BXDriveImport baseNameForDrive: drive];
	NSString *importedName = [baseName stringByAppendingPathExtension: @"iso"];
	
	return importedName;
}


#pragma mark -
#pragma mark Initialization and deallocation

- (id <BXDriveImport>) init
{
	if ((self = [super init]))
	{
		self.indeterminate = YES;
	}
	return self;
}

- (id <BXDriveImport>) initForDrive: (BXDrive *)drive
               destinationFolderURL: (NSURL *)destinationFolderURL
						  copyFiles: (BOOL)copy;
{
	if ((self = [self init]))
	{
        self.drive = drive;
        self.destinationFolderURL = destinationFolderURL;
	}
	return self;
}


#pragma mark -
#pragma mark The actual operation

- (NSUInteger) numFiles
{
	//An ISO rip operation always results in a single ISO file being generated.
    return 1;
}
- (NSUInteger) filesTransferred
{
    return self.succeeded ? 1 : 0;
}

- (NSString *) currentPath
{
    return self.isFinished ? nil : self.drive.sourceURL.path;
}

- (BOOL) copyFiles
{
	return YES;
}

- (void) setCopyFiles: (BOOL)flag
{
	//An ISO rip operation is always a copy, so this is a no-op
}

- (NSURL *) preferredDestinationURL
{
    if (!self.drive || !self.destinationFolderURL) return nil;
    
	NSString *driveName			= [self.class nameForDrive: self.drive];
    NSURL *destinationURL       = [self.destinationFolderURL URLByAppendingPathComponent: driveName];
    
    //Check that there isn't already a file with the same name at the location.
    //If there is, auto-increment the name until we land on one that's unique.
    NSURL *uniqueDestinationURL = [[NSFileManager defaultManager] uniqueURLForURL: destinationURL
                                                                   filenameFormat: BXUniqueDriveNameFormat];
    
    return uniqueDestinationURL;
}

- (void) main
{
    NSAssert(self.drive != nil, @"No drive provided for drive import operation.");
    NSAssert(self.destinationURL != nil || self.destinationFolderURL != nil, @"No destination folder provided for drive import operation.");
    
    if (!self.destinationURL)
        self.destinationURL = self.preferredDestinationURL;
    
	NSURL *sourceURL        = self.drive.sourceURL;
	NSURL *destinationURL	= self.destinationURL;
	
    
	//Measure the size of the volume to determine how much data we'll be importing
    NSNumber *volumeSizeResource;
	NSError *volumeSizeError;
    BOOL gotVolumeSize = [sourceURL getResourceValue: &volumeSizeResource
                                              forKey: NSURLVolumeTotalCapacityKey
                                               error: &volumeSizeError];
    
    if (gotVolumeSize)
    {
        self.numBytes = volumeSizeResource.unsignedLongLongValue;
    }
    else
    {
        self.error = volumeSizeError;
        return;
    }
	
	//Determine the /dev/diskx device name of the volume
	NSString *deviceName = [[NSWorkspace sharedWorkspace] BSDDeviceNameForVolumeAtURL: sourceURL];
	if (!deviceName)
	{
		NSError *unknownDeviceError = [NSError errorWithDomain: NSCocoaErrorDomain
														  code: NSFileReadUnknownError
													  userInfo: @{ NSURLErrorKey: sourceURL }];
		self.error = unknownDeviceError;
		return;
	}
	
	//If the destination filename doesn't end in .cdr, then hdiutil will add it itself:
	//so we'll do so for it, to ensure we know exactly what the destination path will be.
	NSURL *tempDestinationURL = destinationURL;
	if (![destinationURL.pathExtension.lowercaseString isEqualToString: @"cdr"])
	{
		tempDestinationURL = [destinationURL URLByAppendingPathExtension: @"cdr"];
	}
	
	//Prepare the hdiutil task
	NSTask *hdiutil = [[NSTask alloc] init];
	NSArray *arguments = [NSArray arrayWithObjects:
						  @"create",
						  @"-srcdevice", deviceName,
						  @"-format", @"UDTO",
						  @"-puppetstrings",
						  tempDestinationURL.path,
						  nil];
	
	hdiutil.launchPath = @"/usr/bin/hdiutil";
	hdiutil.arguments = arguments;
	hdiutil.standardOutput = [NSPipe pipe];
	hdiutil.standardError = [NSPipe pipe];
	
	self.task = hdiutil;
	
	//Run the task to completion and monitor its progress
    self.hasWrittenFiles = NO;
	[super main];
    self.hasWrittenFiles = YES;
	
	if (!self.error)
	{
		//If image creation succeeded, then rename the new image to its final destination name
		if ([tempDestinationURL checkResourceIsReachableAndReturnError: NULL])
		{
			if (![tempDestinationURL isEqual: destinationURL])
			{
                NSError *renameError = nil;
				BOOL moved = [[NSFileManager defaultManager] moveItemAtURL: tempDestinationURL
                                                                     toURL: destinationURL
                                                                     error: &renameError];
                
                if (!moved)
                {
                    self.error = renameError;
                }
			}
		}
		else
		{
			self.error = [BXCDImageImportRipFailedError errorWithDrive: self.drive];
		}
	}
    
    
    //If the import failed for any reason (including cancellation),
    //then clean up the partial files.
    if (self.error)
    {
        [self undoTransfer];
    }
}

- (void) checkTaskProgress: (NSTimer *)timer
{
    NSTask *task = timer.userInfo;
	NSFileHandle *outputHandle = [task.standardOutput fileHandleForReading];
	
	NSString *currentOutput = [[NSString alloc] initWithData: outputHandle.availableData
                                                    encoding: NSUTF8StringEncoding];
	NSArray *progressValues = [currentOutput componentsMatchedByRegex: @"PERCENT:(-?[0-9\\.]+)" capture: 1];
	
	ADBOperationProgress latestProgress = [progressValues.lastObject floatValue];
	
	if (latestProgress > 0)
	{
		self.indeterminate = NO;
		//hdiutil expresses progress as a float percentage from 0 to 100
		self.currentProgress = latestProgress / 100.0f;
		self.bytesTransferred = (self.numBytes * (double)self.currentProgress);
		
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithUnsignedLongLong:	self.bytesTransferred],	ADBFileTransferBytesTransferredKey,
							  [NSNumber numberWithUnsignedLongLong:	self.numBytes],			ADBFileTransferBytesTotalKey,
							  nil];
		[self _sendInProgressNotificationWithInfo: info];
	}
	//hdiutil will print "-1" when its own progress is indeterminate
	//q.v. man hdiutil and search for -puppetstrings
	else if (latestProgress == -1)
	{
		self.indeterminate = YES;
		[self _sendInProgressNotificationWithInfo: nil];
	}
}


- (BOOL) undoTransfer
{
	BOOL undid = NO;
	if (self.destinationURL && self.hasWrittenFiles)
	{
        undid = [[NSFileManager defaultManager] removeItemAtURL: self.destinationURL error: NULL];
	}
	return undid;
}

@end


@implementation BXCDImageImportRipFailedError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *displayName = drive.title;
	NSString *descriptionFormat = NSLocalizedString(@"The disc “%1$@” could not be converted into a disc image.",
													@"Error shown when CD-image ripping fails for an unknown reason. %1$@ is the display title of the drive.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, displayName];
	NSDictionary *userInfo	= @{
                                NSLocalizedDescriptionKey: description,
                                NSURLErrorKey: drive.sourceURL,
                                };
	
	return [NSError errorWithDomain: BXCDImageImportErrorDomain
                               code: BXCDImageImportErrorRipFailed
                           userInfo: userInfo];
}
@end


@implementation BXCDImageImportDiscInUseError

+ (id) errorWithDrive: (BXDrive *)drive
{
	NSString *displayName = drive.title;
	NSString *descriptionFormat = NSLocalizedString(@"The disc “%1$@” could not be converted to a disc image because it is in use by another application.",
													@"Error shown when CD-image ripping fails because the disc is in use. %1$@ is the display title of the drive.");
	
	NSString *description	= [NSString stringWithFormat: descriptionFormat, displayName];
	NSString *suggestion	= NSLocalizedString(@"Close Finder windows or other applications that are using the disc, then try importing again.", @"Explanatory message shown when CD-image ripping fails because the disc is in use.");
	
	NSDictionary *userInfo	= @{
                                NSLocalizedDescriptionKey: description,
                                NSLocalizedRecoverySuggestionErrorKey: suggestion,
                                NSURLErrorKey: drive.sourceURL
                                };
	
	return [NSError errorWithDomain: BXCDImageImportErrorDomain
                               code: BXCDImageImportErrorDiscInUse
                           userInfo: userInfo];
}
@end
