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

//Contains protected API that should only be used by ADBLocalFilesystem subclasses.

#import <Foundation/Foundation.h>
#import "ADBLocalFilesystem.h"

NS_ASSUME_NONNULL_BEGIN

@interface ADBLocalFilesystem () <NSFileManagerDelegate>

/// Our own file manager for internal use.
@property (strong, nonatomic) NSFileManager *manager;

/// A base implementation for copyItemAtPath:toPath:error: and moveItemAtPath:toPath:error:,
/// which share 95% of their logic.
- (BOOL) _transferItemAtPath: (NSString *)fromPath
                      toPath: (NSString *)toPath
                     copying: (BOOL)copying
                       error: (out NSError *_Nullable*_Nullable)outError;

@end

/// An extremely thin wrapper for an NSDirectoryEnumerator to implement
/// the @c ADBFilesystem enumeration protocols and allow filesystem-relative
/// paths to be returned.
@interface ADBLocalDirectoryEnumerator : NSEnumerator <ADBFilesystemPathEnumeration, ADBFilesystemFileURLEnumeration>
{
    BOOL _returnsFileURLs;
    NSDirectoryEnumerator *_enumerator;
    ADBLocalFilesystem *_filesystem;
    NSURL *_currentURL;
}

@property (copy, nonatomic) NSURL *currentURL;
@property (strong, nonatomic) NSDirectoryEnumerator *enumerator;
@property (strong, nonatomic) ADBLocalFilesystem *filesystem;

- (instancetype) initWithURL: (NSURL *)localURL
                 inFilesytem: (ADBLocalFilesystem *)filesystem
  includingPropertiesForKeys: (nullable NSArray<NSURLResourceKey> *)keys
                     options: (NSDirectoryEnumerationOptions)mask
                  returnURLs: (BOOL)returnURLs
                errorHandler: (nullable ADBFilesystemFileURLErrorHandler)errorHandler;

@end

NS_ASSUME_NONNULL_END
