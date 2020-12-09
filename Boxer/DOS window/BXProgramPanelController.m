/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXProgramPanelController.h"
#import "BXValueTransformers.h"
#import "BXSession+BXFileManagement.h"
#import "BXProgramPanel.h"
#import "BXGamebox.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "NSString+ADBPaths.h"
#import "BXDOSWindowController.h"
#import "ADBForwardCompatibility.h"


@interface BXProgramPanelController ()
@property (readwrite, strong, nonatomic) NSArray *panelExecutables;
@end

@implementation BXProgramPanelController

- (void) dealloc
{
	[NSThread cancelPreviousPerformRequestsWithTarget: self];
	
	[self setProgramList: nil];
	[self setProgramScroller: nil];
    [self setScanSpinner: nil];
	
	[self setDefaultProgramPanel: nil];
	[self setInitialDefaultProgramPanel: nil];
	[self setProgramChooserPanel: nil];
	[self setNoProgramsPanel: nil];
	[self setScanningForProgramsPanel: nil];
    
	[self setPanelExecutables: nil];
    [self setLastActiveProgramPath: nil];
}

- (NSString *) nibName	{ return @"ProgramPanel"; }

+ (void) initialize
{
    if (self == [BXProgramPanelController class])
    {
        id displayPath	= [[BXDisplayPathTransformer alloc]	initWithJoiner: @" ▸ " maxComponents: 3];
        id fileName		= [[BXDOSFilenameTransformer alloc] init];

        [NSValueTransformer setValueTransformer: displayPath forName: @"BXProgramDisplayPath"];
        [NSValueTransformer setValueTransformer: fileName forName: @"BXDOSFilename"];
    }
}

- (void) setRepresentedObject: (id)session
{
	if ([self representedObject])
	{
		[[self representedObject] removeObserver: self forKeyPath: @"programURLsOnPrincipalDrive"];
		[[self representedObject] removeObserver: self forKeyPath: @"gamebox.legacyTargetURL"];
		[[self representedObject] removeObserver: self forKeyPath: @"launchedProgramURL"];
		[[self representedObject] removeObserver: self forKeyPath: @"isScanningForExecutables"];
	}
	
	[super setRepresentedObject: session];
	
	if (session)
	{
		[session addObserver: self forKeyPath: @"programURLsOnPrincipalDrive" options: 0 context: nil];
		[session addObserver: self forKeyPath: @"gamebox.legacyTargetURL" options: 0 context: nil];
		[session addObserver: self forKeyPath: @"launchedProgramURL" options: 0 context: nil];
		[session addObserver: self forKeyPath: @"isScanningForExecutables" options: 0 context: nil];
	}
}

//Whenever the active program changes, change which view is drawn
- (void)observeValueForKeyPath: (NSString *)keyPath
					  ofObject: (id)object
						change: (NSDictionary *)change
					   context: (void *)context
{
	if ([keyPath isEqualToString: @"programURLsOnPrincipalDrive"] || [keyPath isEqualToString: @"gamebox.legacyTargetURL"])
	{
		[self syncPanelExecutables];
	}
    
    else if ([keyPath isEqualToString: @"launchedProgramURL"])
    {
        NSString *path = [(BXSession *)object launchedProgramURL].path;
        if (path) [self setLastActiveProgramPath: path];
    }
    
    //Update the current panel after any change we're listening for
	//(Update the panel contents after a short delay, to allow time for a program
    //to quit at startup - this way we don't flash one panel and then go straight back to another.)
	[self performSelector: @selector(syncActivePanel) withObject: nil afterDelay: 0.2];
}

- (void) setView: (NSView *)view
{
	[super setView: view];
	//This will pull our subsidiary views from our own NIB file
	[self loadView];
}

- (void) awakeFromNib
{
    //Disable vertical scrolling on 10.7: while we can only scroll horizontally, it's still otherwise
    //possible for the user to pull on the content vertically, and this causes ugly redraw errors.
    if ([[self programScroller] respondsToSelector: @selector(setVerticalScrollElasticity:)])
    {
        [[self programScroller] setVerticalScrollElasticity: NSScrollElasticityNone];
    }
}

- (void) syncActivePanel
{	
	BXSession *session = [self representedObject];
	NSView *panel;
	
	//Show the 'make this program the default' panel only when the session's active program
	//can be legally set as the default target (i.e., it's located within the gamebox)
	if ([self canSetActiveProgramToDefault])
	{	
		//If we have a default program, show the checkbox version;
		//also keep showing the checkbox if it's already active
		if ([self hasDefaultTarget] || [self activePanel] == self.defaultProgramPanel)
			panel = self.defaultProgramPanel;
		//Otherwise, show the Yes/No choice.
		else
			panel = self.initialDefaultProgramPanel;
	}
	else if	(session.programURLsOnPrincipalDrive)
	{
		panel = self.programChooserPanel;
        [self syncProgramButtonStates];
	}
    else if ([session isScanningForExecutables])
    {
        panel = self.scanningForProgramsPanel;
    }
    else
    {   
		panel = self.noProgramsPanel;
    }

	[self setActivePanel: panel];
}

- (void) syncProgramButtonStates
{
	for (NSView *itemView in [self.programList subviews])
	{
		NSButton *button = [itemView viewWithTag: BXProgramPanelButtons];
		
		//Validate the program chooser buttons, which will enable/disable them based
        //on whether we're at the DOS prompt or not.
		//This would be much simpler with a binding but HA HA HA HA we can't because
		//Cocoa doesn't clean up bindings on NSCollectionView subviews properly,
		//causing spurious exceptions once the thing we're observing has been dealloced.
		[button setEnabled: [[self representedObject] validateUserInterfaceItem: (id)button]];
        
        //Force each button to update its tracking area also, which will resyc
        //its mouseover state. This is necessary to prevent 'sticky' mouse-hover
        //highlights when pressing a button has switched the current panel.
        [button updateTrackingAreas];
	}
}

- (NSView *) activePanel
{
	return [[[self view] subviews] lastObject];
}

- (void) setActivePanel: (NSView *)panel
{
	NSView *previousPanel = [self activePanel];
    
	if (previousPanel != panel)
	{
		NSView *mainView = [self view];
		
		//Resize the panel to fit the current container size,
        //and unhide it if it was previously hidden
		[panel setFrame: [mainView bounds]];
		[panel setHidden: NO];
        
		//Add the new panel into the view
        //If there's a previous panel on display, then fade out the old panel
        [mainView addSubview: panel positioned: NSWindowBelow relativeTo: previousPanel];
        if (previousPanel && ![mainView isHidden])
        {
            
            NSDictionary *fadeOut = [NSDictionary dictionaryWithObjectsAndKeys:
                                     previousPanel, NSViewAnimationTargetKey,
                                     NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey,
                                     nil];
            
            NSViewAnimation *animation = [[NSViewAnimation alloc] init];
            [animation setAnimationBlockingMode: NSAnimationBlocking];
            [animation setViewAnimations: [NSArray arrayWithObject: fadeOut]];
            [animation setDuration: 0.25];
            [animation startAnimation];
        }
        [previousPanel removeFromSuperview];
        [mainView setNeedsDisplay: YES];
	}
}

//Returns the display string used for the "open this program every time" checkbox toggle
- (NSString *) labelForDefaultProgramToggle
{
    NSString *programPath = [self lastActiveProgramPath];
    if (programPath)
    {
        NSString *format = NSLocalizedString(
            @"Launch %@ every time I open this gamebox.",
            @"Label for default program checkbox in program panel. %@ is the lowercase filename of the currently-active program."
        );
        
        NSString *displayName = [[NSValueTransformer valueTransformerForName: @"BXDOSFilename"] transformedValue: programPath];
        return [NSString stringWithFormat: format, displayName];
    }
    else return nil;
}

- (NSString *) labelForInitialDefaultProgramToggle
{
    NSString *programPath = [self lastActiveProgramPath];
	if (programPath)
    {
        NSString *format = NSLocalizedString(
            @"Launch %@ every time?",
            @"Label for initial default-program question in program panel. %@ is the lowercase filename of the currently-active program."
        );
        
        NSString *displayName = [[NSValueTransformer valueTransformerForName: @"BXDOSFilename"] transformedValue: programPath];
        return [NSString stringWithFormat: format, displayName];
    }
    else return nil;
}

+ (NSSet *) keyPathsForValuesAffectingLabelForDefaultProgramToggle
{
    return [NSSet setWithObject: @"lastActiveProgramPath"];
}

+ (NSSet *) keyPathsForValuesAffectingLabelForInitialDefaultProgramToggle
{
    return [NSSet setWithObject: @"lastActiveProgramPath"];
}

- (BOOL) activeProgramIsDefault
{
	BXSession *session = self.representedObject;
    
	NSString *activeProgram = self.lastActiveProgramPath;

    NSString *defaultProgram = session.gamebox.legacyTargetURL.path;
    return [activeProgram isEqualToString: defaultProgram];
}

+ (NSSet *)keyPathsForValuesAffectingActiveProgramIsDefault
{
	return [NSSet setWithObjects:
			@"lastActiveProgramPath",
			@"representedObject.gamebox.legacyTargetURL",
			nil];
}

- (void) setActiveProgramIsDefault: (BOOL) isDefault
{	
	BXSession *session = self.representedObject;
    
	BXGamebox *gamebox	= session.gamebox;
	NSURL *activeProgramURL	= session.launchedProgramURL;
    
	if (!gamebox || !activeProgramURL) return;
	
	if (isDefault)
        gamebox.targetPath = activeProgramURL.path;
    
	else if (self.activeProgramIsDefault)
        gamebox.targetPath = nil;
}

- (BOOL) canSetActiveProgramToDefault
{
 	BXSession *session = self.representedObject;
	NSString *activeProgram = session.launchedProgramURL.path;
    
	return (activeProgram != nil) && [session.gamebox validateTargetPath: &activeProgram error: NULL];
}

- (BOOL) hasDefaultTarget
{
	BXSession *session = self.representedObject;
	return (session.gamebox.targetPath != nil);
}


#pragma mark -
#pragma mark IB actions

- (IBAction) setCurrentProgramToDefault: (id)sender
{
	[NSApp sendAction: @selector(toggleProgramPanelShown:) to: nil from: self];
	if ([self canSetActiveProgramToDefault]) [self setActiveProgramIsDefault: YES];
}

#pragma mark -
#pragma mark Executable list

- (void) syncPanelExecutables
{
	BXSession *session = self.representedObject;
	
	NSString *defaultTarget	= session.gamebox.targetPath;
	NSArray *programPaths	= [session.programURLsOnPrincipalDrive valueForKey: @"path"];
	
	//Filter the program list to just the topmost files
	NSArray *filteredPaths = [programPaths pathsFilteredToDepth: 0];
	
	//If the target program isn't in the list, and it is actually available in DOS, add it in too
	if (defaultTarget && ![filteredPaths containsObject: defaultTarget] &&
		[[session emulator] DOSPathExists: defaultTarget])
		filteredPaths = [filteredPaths arrayByAddingObject: defaultTarget];
	
	NSMutableSet *programNames = [[NSMutableSet alloc] initWithCapacity: [filteredPaths count]];
	NSMutableArray *listedPrograms = [[NSMutableArray alloc] initWithCapacity: [filteredPaths count]];
	
	for (NSString *path in filteredPaths)
	{
		BOOL isDefaultTarget = [path isEqualToString: defaultTarget];
		
		NSString *fileName = [path lastPathComponent];
		
		//If we already have an executable with this name,
		//skip it so that we don't offer ambiguous choices (unless it's the default target)
		if (isDefaultTarget || ![programNames containsObject: fileName])
		{
			NSDictionary *data	= [[NSDictionary alloc] initWithObjectsAndKeys:
								   path, @"path",
								   [NSNumber numberWithBool: isDefaultTarget], @"isDefault",
								   nil];
			
			[programNames addObject: fileName];
			[listedPrograms addObject: data];
		}
	}
    
    //We check here if anything has actually changed, to avoid triggering
    //unnecessary redraws in the program panel.
    if (![[self panelExecutables] isEqualToArray: listedPrograms])
	    [self setPanelExecutables: listedPrograms];
}

- (NSArray *) executableSortDescriptors
{
	NSSortDescriptor *sortDefaultFirst = [[NSSortDescriptor alloc] initWithKey: @"isDefault" ascending: NO];
	
	NSSortDescriptor *sortByFilename = [[NSSortDescriptor alloc] initWithKey: @"path.lastPathComponent"
																   ascending: YES
																	selector: @selector(caseInsensitiveCompare:)];
	
    return @[sortDefaultFirst, sortByFilename];
}

@end
