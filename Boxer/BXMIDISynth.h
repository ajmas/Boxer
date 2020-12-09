/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXMIDISyth sending MIDI signals from DOSBox to OS X's built-in MIDI synth, using the AUGraph API.
//It's largely cribbed from DOSBox's own coreaudio MIDI handler.

#import "BXMIDIDevice.h"
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class BXEmulator;

/// BXMIDISyth sending MIDI signals from DOSBox to OS X's built-in MIDI synth, using the AUGraph API.
/// It's largely cribbed from DOSBox's own coreaudio MIDI handler.
@interface BXMIDISynth : NSObject <BXMIDIDevice>

/// The URL of the soundfont bank we are currently using,
/// which be the default system unless a custom one has been
/// set with \c loadSoundFontWithContentsOfURL:error:
@property (readonly, copy, nonatomic) NSURL *soundFontURL;

/// Returns the URL of the default system soundfont.
@property (readonly, copy, class) NSURL *defaultSoundFontURL;

/// Returns a fully-initialized synth ready to receive MIDI messages.
/// Returns \c nil and populates \c outError if the synth could not be initialised.
- (nullable instancetype) initWithError: (NSError **)outError;

/// Sets the specified soundfont with which MIDI should be played back.
/// \c soundFontURL will be updated with the specified URL.
///
/// Pass \c nil as the path to clear a previous custom soundfont and revert
/// to using the system soundfont.
///
/// Returns \c YES if the soundfont was loaded/cleared, or \c NO and populates
/// \c outError if the soundfont couldn't be loaded for any reason (in which
/// case \c soundFontURL will remain unchanged.)
- (BOOL) loadSoundFontWithContentsOfURL: (nullable NSURL *)URL error: (NSError **)outError;

@end

NS_ASSUME_NONNULL_END
