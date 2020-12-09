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

#import "ADBImageAwareFileScan.h"
#import "NSWorkspace+ADBMountedVolumes.h"
#import "NSWorkspace+ADBFileTypes.h"


@implementation ADBImageAwareFileScan
@synthesize mountedVolumePath = _mountedVolumePath;
@synthesize ejectAfterScanning = _ejectAfterScanning;
@synthesize didMountVolume = _didMountVolume;

- (id) init
{
    if ((self = [super init]))
    {
        self.ejectAfterScanning = ADBFileScanEjectIfSelfMounted;
    }
    return self;
}

- (NSString *) fullPathFromRelativePath: (NSString *)relativePath
{
    //Return paths relative to the mounted volume instead, if available.
    NSString *filesystemRoot = (self.mountedVolumePath) ? self.mountedVolumePath : self.basePath;
    return [filesystemRoot stringByAppendingPathComponent: relativePath];
}

//If we have a mounted volume path for an image, enumerate that instead of the original base path
- (NSDirectoryEnumerator *) enumerator
{
    if (self.mountedVolumePath)
        return [_manager enumeratorAtPath: self.mountedVolumePath];
    else return [super enumerator];
}

//Split the work up into separate stages for easier overriding in subclasses.
- (void) main
{
    [self mountVolumesForScan];
    if (!self.isCancelled)
        [self performScan];
    [self unmountVolumesForScan];
}

- (void) performScan
{
    [super main];
}

- (void) mountVolumesForScan
{
    NSString *volumePath = nil;
    _didMountVolume = NO;
    
    //If the target path is on a disk image, then mount the image for scanning
    if ([_workspace file: self.basePath matchesTypes: [NSSet setWithObject: @"public.disk-image"]])
    {
        NSURL *baseURL = [NSURL fileURLWithPath: self.basePath];
        
        //First, check if the image is already mounted
        volumePath = [[[_workspace mountedVolumeURLsForSourceImageAtURL: baseURL] firstObject] path];
        
        //If it's not mounted yet, mount it ourselves
        if (!volumePath)
        {
            NSError *mountError = nil;
            ADBImageMountingOptions options = ADBMountReadOnly | ADBMountInvisible;
            NSArray<NSURL *> *images = [_workspace mountImageAtURL: baseURL
                                                           options: options
                                                             error: &mountError];
            
            if (images.count > 0)
            {
                _didMountVolume = YES;
                volumePath = [images.firstObject path];
            }
            //If we couldn't mount the image, give up in failure
            else
            {
                self.error = mountError;
                [self cancel];
                return;
            }
        }
        
        self.mountedVolumePath = volumePath;
    }
}

- (void) unmountVolumesForScan
{
    //If we mounted a volume ourselves in order to scan it,
    //or we've been told to always eject, then unmount the volume
    //once we're done
    if (self.mountedVolumePath)
    {
        if ((self.ejectAfterScanning == ADBFileScanAlwaysEject) ||
            (_didMountVolume && self.ejectAfterScanning == ADBFileScanEjectIfSelfMounted))
        {
            [_workspace unmountAndEjectDeviceAtPath: self.mountedVolumePath];
            self.mountedVolumePath = nil;
        }
    }    
}

@end
