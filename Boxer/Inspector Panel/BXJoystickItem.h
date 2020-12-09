/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXCollectionItemView.h"

@interface BXJoystickItem : BXCollectionItem

@property (strong, nonatomic, null_unspecified) IBOutlet NSTextField *titleLabel;
@property (strong, nonatomic, null_unspecified) IBOutlet NSTextField *descriptionLabel;
@property (strong, nonatomic, null_unspecified) IBOutlet NSImageView *icon;

@end
