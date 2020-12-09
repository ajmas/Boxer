/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

//The ADBMountedVolumes category adds methods to NSWorkspace to retrieve all volumes of a certain type,
//and to determine the source image for a mounted volume using HDIUtil.

//Note that many of these methods may block for a long time if a mounted network volume is unavailable:
//NSWorkspace and/or HDIUtil have to wait for network volume connections to time out.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN


#pragma mark - Volume-type constants

/// Filesystem types, for use with @c mountedVolumesOfType:
typedef NSString *ADBVolumeType NS_STRING_ENUM;
extern ADBVolumeType const ADBDataCDVolumeType NS_SWIFT_NAME(dataCD);
extern ADBVolumeType const ADBAudioCDVolumeType NS_SWIFT_NAME(audioCD);
extern ADBVolumeType const ADBFATVolumeType NS_SWIFT_NAME(FAT);
extern ADBVolumeType const ADBHFSVolumeType NS_SWIFT_NAME(HFS);
extern ADBVolumeType const ADBAPFSVolumeType NS_SWIFT_NAME(APFS);


#pragma mark - Error constants


/// Error domains and userInfo keys
extern NSErrorDomain const ADBMountedVolumesErrorDomain;

//Mount-related error codes
NS_ERROR_ENUM(ADBMountedVolumesErrorDomain)
{
	/// Produced when hdiutil cannot mount the image passed to @c mountImageAtURL:options:error:
	ADBMountedVolumesHDIUtilAttachFailed,
    
    /// Produced when hdiutil failed to return volume data. Returned by @c mountedImageInfoWithError:
    ADBMountedVolumesHDIUtilInfoFailed,
};

typedef NS_OPTIONS(NSUInteger, ADBImageMountingOptions) {
    ADBMountReadOnly NS_SWIFT_NAME(readOnly) = 1 << 0,   //!< Mount the image as a read-only volume
    ADBMountInvisible NS_SWIFT_NAME(invisible) = 1 << 1, //!< Hide the mounted volume from Finder
    ADBMountRaw NS_SWIFT_NAME(raw) = 1 << 2,             //!< Force the image to be mounted as raw
};



#pragma mark - Interface

/// The @c ADBMountedVolumes category adds methods to NSWorkspace to retrieve all volumes of a certain type,
/// and to determine the source image for a mounted volume using HDIUtil.
///
/// Note that many of these methods may block for a long time if a mounted network volume is unavailable:
/// NSWorkspace and/or HDIUtil have to wait for network volume connections to time out.
@interface NSWorkspace (ADBMountedVolumes)

/// The UTIs of disk image formats that @c mountImageAtURL:options:error:
/// will automatically treat as raw images.
@property (class, strong, readonly) NSSet<NSString*> *rawImageTypes;

#pragma mark - Introspecting mounted volumes

/// Returns an array of the URLs of all locally-mounted volumes, i.e. excluding network volumes.
/// If @c hidden is YES, this will include invisible volumes.
/// Note that this will block and can take a significant time to return if a volume has been
/// disconnected unexpectedly or is not responding.
- (nullable NSArray<NSURL*> *) mountedVolumeURLsIncludingHidden: (BOOL)hidden;

/// Returns the URLs all mounted filesystems of the specified filesystem type.
- (NSArray<NSURL*> *) mountedVolumeURLsOfType: (ADBVolumeType)volumeType
                              includingHidden: (BOOL)hidden;

/// Returns whether the volume at the specified file path is visible in Finder.
/// If this is NO, it means the volume has been mounted hidden.
- (BOOL) isVisibleVolumeAtURL: (NSURL *)URL;

/// Returns the underlying filesystem type of the specified URL.
- (nullable ADBVolumeType) typeOfVolumeAtURL: (NSURL *)URL;


#pragma mark - Dealing with mounted images

/// Tells @c hdiutil to mount the specified disk image with the specified volume options.
/// On success, returns an array of one or more URLs representing volumes mounted from
/// the image.
/// On failure, returns @c nil and populates outError.
- (nullable NSArray<NSURL*> *) mountImageAtURL: (NSURL *)URL
                                       options: (ADBImageMountingOptions)options
                                         error: (out NSError **)outError;

/// Returns structured plist info from hdiutil about mounted images and their volumes.
/// Returns @c nil and populates @c outError if the information could not be retrieved.
- (nullable NSArray *) mountedImageInfoWithError: (out NSError **)outError;

/// Returns the URL of the source disk image from which the specified volume path was mounted.
/// Returns @c nil if the source image could not be determined (e.g. if the volume is not mounted
/// from a disk image.)
- (nullable NSURL *) sourceImageForVolumeAtURL: (NSURL *)volumeURL;

/// Returns all volume URLs mounted from the specified source disk image.
/// Returns an empty array if the source image is not currently mounted.
- (NSArray<NSURL*> *) mountedVolumeURLsForSourceImageAtURL: (NSURL *)volumeURL;


#pragma mark - Dealing with mounted CD-ROMs

/// Returns the URL of the data volume associated with the specified CD volume.
/// Returns @c nil if the CD volume has no corresponding data volume.
- (nullable NSURL *) dataVolumeOfAudioCDAtURL: (NSURL *)audioCDURL;

/// Returns the URL of the audio CD volume associated with the specified data CD volume.
/// Returns @c nil if the CD volume has no corresponding audio volume.
- (nullable NSURL *) audioVolumeOfDataCDAtURL: (NSURL *)dataCDURL;

/// Returns @c YES if the specified path points to the HFS volume of a hybrid Mac+PC CD,
/// @c NO otherwise.
- (BOOL) isHybridCDAtURL: (NSURL *)volumeURL;

/// When given a path to the HFS volume of a hybrid Mac+PC CD, returns the BSD device name
/// of the corresponding ISO volume. Returns @c nil if the path was not a hybrid CD or if no
/// matching device name could be determined.
- (nullable NSString *) BSDDeviceNameForISOVolumeOfHybridCDAtURL: (NSURL *)volumeURL;


#pragma mark - Dealing with mounted floppy disks

/// Returns whether the specified volume appears to be a FAT-formatted floppy disk.
- (BOOL) isFloppyVolumeAtURL: (NSURL *)volumeURL;


#pragma mark - Low-level methods

/// Returns the BSD device name (dev/diskXsY) for the specified volume.
/// Returns @c nil if no matching device name could be determined.
- (nullable NSString *) BSDDeviceNameForVolumeAtURL: (NSURL *)volumeURL;

@end

NS_ASSUME_NONNULL_END

#pragma mark - Creaky old NSString path API

@interface NSWorkspace (ADBMountedVolumesLegacyPathAPI)

/// Returns an array of visible locally mounted volumes.
/// If @c hidden is YES, or on 10.5, this will also include invisible volumes.
- (null_unspecified NSArray *) mountedLocalVolumePathsIncludingHidden: (BOOL)hidden __deprecated;

/// Returns whether the volume at the specified file path is visible in Finder.
/// If this is NO, it means the volume has been mounted hidden (and should probably be ignored.)
- (BOOL) volumeIsVisibleAtPath: (null_unspecified NSString *)path __deprecated;

/// Returns all mounted filesystems of the specified filesystem type.
/// If hidden is YES, or on 10.5, this will also include invisible volumes.
- (null_unspecified NSArray *) mountedVolumesOfType: (null_unspecified NSString *)volumeType includingHidden: (BOOL)hidden __deprecated;

/// Returns the underlying filesystem type of the specified path.
- (null_unspecified NSString *) volumeTypeForPath: (null_unspecified NSString *)path __deprecated;

/// Return the base volume path upon which the specified path resides.
- (null_unspecified NSString *) volumeForPath: (null_unspecified NSString *)path __deprecated;

/// Returns the path to the source disk image from which the specified volume path was created.
/// Returns nil if the source image could not be determined (e.g. if the volume is not mounted from a disk image)
- (null_unspecified NSString *) sourceImageForVolume: (null_unspecified NSString *)volumePath __deprecated;

/// Returns the first path at which the specified source disk image is mounted.
/// Returns nil if the source image is not currently mounted.
- (null_unspecified NSString *) volumeForSourceImage: (null_unspecified NSString *)imagePath __deprecated;

/// Mounts the disk image at the specified path, and returns the path to the newly-mounted volume if successful.
/// Returns nil and populates error if mounting failed.
/// If invisible is true, the mounted volume will not appear in Finder.
- (null_unspecified NSString *) mountImageAtPath: (null_unspecified NSString *)path
					   readOnly: (BOOL)readOnly
					  invisibly: (BOOL)invisible
						  error: (NSError *_Null_unspecified*_Null_unspecified)error __deprecated;

/// Returns the path of the data volume associated with the specified CD volume path.
/// Returns nil if the CD volume has no corresponding data volume.
- (null_unspecified NSString *) dataVolumeOfAudioCD: (null_unspecified NSString *)volumePath __deprecated;

/// Returns the path of the audio CD volume associated with the specified data CD volume path.
/// Returns nil if the CD volume has no corresponding audio volume.
- (null_unspecified NSString *) audioVolumeOfDataCD: (null_unspecified NSString *)volumePath __deprecated;

/// Returns whether the specified volume is actually a DOS floppy disk.
- (BOOL) isFloppyVolumeAtPath: (null_unspecified NSString *)volumePath __deprecated;

/// Returns whether the specified volume is the size of a DOS floppy disk.
- (BOOL) isFloppySizedVolumeAtPath: (null_unspecified NSString *)volumePath __deprecated;

@end
