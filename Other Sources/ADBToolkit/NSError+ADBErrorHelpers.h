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

//ADBErrorHelpers adds helper methods to NSError to make it nicer to work with.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// ADBErrorHelpers adds helper methods to @c NSError to make it nicer to work with.
@interface NSError (ADBErrorHelpers)

/// Returns @c YES if the error has the specified error domain and code, @c NO otherwise.
- (BOOL) matchesDomain: (NSErrorDomain)errorDomain code: (NSInteger)errorCode;

/// Whether this is a standard Cocoa user-cancelled-operation error.
@property (readonly, getter=isUserCancelledError) BOOL userCancelledError;

@end


/// Keys included in @c callstackDescriptions dictionaries
typedef NSString *ADBCallstackKeys NS_STRING_ENUM;
/// The raw output of callstack_symbols.
extern ADBCallstackKeys const ADBCallstackRawSymbol;
/// The name of the binary in which the stack entry is located.
extern ADBCallstackKeys const ADBCallstackLibraryName;
/// The memory address of the stack entry as a hex string.
extern ADBCallstackKeys const ADBCallstackAddress;
/// The raw function name, mangled in the case of C++ and Swift names.
extern ADBCallstackKeys const ADBCallstackFunctionName;
/// For C++ and Swift functions, a demangled version of the function name;
/// otherwise identical to @c ADBCallstackFunctionName
extern ADBCallstackKeys const ADBCallstackHumanReadableFunctionName;
/// An @c NSNumber representing the offset within the function.
extern ADBCallstackKeys const ADBCallstackSymbolOffset;

@interface NSException (ADBExceptionHelpers)

/// Takes a mangled C++ function name produced by @c callstackSymbols or @c backtrace_symbols and returns a demangled version.
/// Returns @c nil if the provided string could not be resolved (which will be the case if it is a C or Objective C symbol name.)
+ (nullable NSString *) demangledCPlusPlusFunctionName: (NSString *)functionName;

/// Returns the results of @c -callstackSymbols parsed into NSDictionaries with the attributes listed above.
- (NSArray<NSDictionary<ADBCallstackKeys, id>*> *) callStackDescriptions;

@end

NS_ASSUME_NONNULL_END
