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

#import <Foundation/Foundation.h>
#import "ADBFilesystemBase.h"

NS_ASSUME_NONNULL_BEGIN

/// ADBLocalFilesystem is a thin implementation of ADBFilesystem protocols which wraps
/// a location on the OS X filesystem.
@interface ADBLocalFilesystem : ADBFilesystemBase <ADBFilesystemPathAccess, ADBFilesystemLogicalURLAccess, ADBFilesystemFileURLAccess>
{
    NSFileManager *_manager;
}

#pragma mark - Constructors

/// Return a new filesystem manager initialised with the specified URL.
+ (instancetype) filesystemWithBaseURL: (NSURL *)baseURL;
- (instancetype) initWithBaseURL: (NSURL *)baseURL;

/// Redeclared to make explicit the ADB*Handle protocols the handle will support.
- (nullable id <ADBFileHandleAccess, ADBReadable, ADBWritable, ADBSeekable>) fileHandleAtPath: (NSString *)path
                                                                                      options: (ADBHandleOptions)options
                                                                                        error: (out NSError **)outError;
@end

NS_ASSUME_NONNULL_END
