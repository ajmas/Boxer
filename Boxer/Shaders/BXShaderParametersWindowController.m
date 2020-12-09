// Copyright (c) 2019, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

@import OpenEmuShaders;

#import "BXShaderParametersWindowController.h"
#import "BXSession.h"
#import "BXDOSWindowController.h"
#import "Boxer-Swift.h"

static NSUserInterfaceItemIdentifier const CheckboxType  = @"Checkbox";
static NSUserInterfaceItemIdentifier const SliderType    = @"Slider";
static NSUserInterfaceItemIdentifier const GroupType     = @"Group";

@interface OEShaderParameter (View)
- (NSString *)selectCellType;
@end

@interface BXShaderParametersWindowController ()<NSOutlineViewDelegate, NSOutlineViewDataSource>
{
    NSArray<OEShaderParameter *> *_params;
}
@end

@implementation BXShaderParametersWindowController

//- (instancetype)initWithGameViewController:(OEGameViewController *)controller
//{
//    if ((self = [super initWithWindowNibName:@"ShaderParameters"]))
//    {
//        _controller = controller;
//    }
//    return self;
//}

- (NSNibName)windowNibName {
    return @"ShaderParameters";
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    OEShaderParameter *param = (OEShaderParameter *)object;
//    [_controller.document gameViewController:_controller
//    setShaderParameterValue:param.value
//                    atIndex:param.index
//               atGroupIndex:param.groupIndex];
    
    
    //[self.shader writeWithParameters:_params identifier:_controller.document.systemIdentifier];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSOutlineView *outlineView = self.outlineView;
    [outlineView setDelegate:self];
    [outlineView setDataSource:self];
    
    [outlineView setHeaderView:nil];
    [outlineView setGridStyleMask:0];
    [outlineView setAllowsColumnReordering:NO];
    [outlineView setAllowsColumnResizing:NO];
    [outlineView setAllowsColumnSelection:NO];
    [outlineView setAllowsEmptySelection:YES];
    [outlineView setAllowsMultipleSelection:NO];
    [outlineView setAllowsTypeSelect:NO];
    
#define CELL(name) [[NSNib alloc] initWithNibNamed:name bundle:nil]
    
    [outlineView registerNib:CELL(@"SliderCell") forIdentifier:SliderType];
    [outlineView registerNib:CELL(@"GroupCell") forIdentifier:GroupType];
    [outlineView registerNib:CELL(@"CheckboxCell") forIdentifier:CheckboxType];
}

- (void)setGroups:(NSArray<OEShaderParamGroup *> *)groups
{
    if ([_groups isEqualTo:groups])
    {
        return;
    }
    
    [self willChangeValueForKey:@"groups"];
    
    NSArray<OEShaderParameter *> *params;
    
    if (groups.count > 1)
    {
        NSMutableArray<OEShaderParamGroup *> *filtered = [NSMutableArray new];
        NSMutableArray *p2 = [NSMutableArray new];
        for (OEShaderParamGroup *g in groups) {
            if (g.hidden) continue; // skip hidden groups
            
            [filtered addObject:g];
            [p2 addObjectsFromArray:g.parameters];
        }
        groups = filtered;
        params = p2;
    }
    else
    {
        params = groups[0].parameters;
    }
    
    _groups = groups;
    
    [self didChangeValueForKey:@"groups"];
    
    self.params = params;
    
    [self.outlineView reloadData];
}

- (void)setParams:(NSArray<OEShaderParameter *> *)params
{
    if ([_params isEqualTo:params])
    {
        return;
    }
    
    [self willChangeValueForKey:@"params"];
    
    if (_params)
    {
        [_params removeObserver:self
           fromObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _params.count)]
                     forKeyPath:@"value"];
    }

    _params = params;
    
    [self didChangeValueForKey:@"params"];
    
    if (_params)
    {
        [_params addObserver:self
          toObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _params.count)]
                  forKeyPath:@"value"
                     options:NSKeyValueObservingOptionNew
                     context:nil];
    }
}

#pragma mark - Actions

- (IBAction)resetAll:(id)sender
{
    [_params enumerateObjectsUsingBlock:^(OEShaderParameter * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.value = obj.initial;
    }];
    
}

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([item isKindOfClass:OEShaderParameter.class])
    {
        OEShaderParameter *param = item;
        NSString *type = [param selectCellType];
        NSView *cellView = [outlineView makeViewWithIdentifier:type owner:self];
        
        if(type == CheckboxType)
        {
            NSButton *checkbox = cellView.subviews.firstObject;
            [checkbox setTitle:param.desc];

            NSDictionary *options = @{ NSContinuouslyUpdatesValueBindingOption:@YES };
            [checkbox bind:@"value" toObject:param withKeyPath:@"value" options:options];
        }
        else if(type == SliderType)
        {
            NSTextField *lbl = cellView.subviews.firstObject;
            [lbl setStringValue:param.desc];
            
            NSSlider  *slid  = [cellView viewWithTag:100];
            slid.continuous  = YES;
            slid.minValue    = param.minimum;
            slid.maxValue    = param.maximum;
            NSUInteger ticks = (NSUInteger)(slid.maxValue - slid.minValue) + 1;
            if (param.step == 1.0 && ticks <= 11)
            {
                slid.numberOfTickMarks        = ticks;
                slid.allowsTickMarkValuesOnly = YES;
            }
            else
            {
                slid.numberOfTickMarks = 0;
                slid.allowsTickMarkValuesOnly = NO;
            }
            
            NSTextField *num  = [cellView viewWithTag:101];
            
            NSStepper *step = [cellView viewWithTag:102];
            step.minValue   = param.minimum;
            step.maxValue   = param.maximum;
            step.increment  = param.step;
            
            NSDictionary *options = @{ NSContinuouslyUpdatesValueBindingOption:@YES };
            
            [slid bind:@"value" toObject:param withKeyPath:@"value" options:options];
            [num bind:@"value" toObject:param withKeyPath:@"value" options:options];
            [step bind:@"value" toObject:param withKeyPath:@"value" options:options];
        }
        
        return cellView;
    }
    
    OEShaderParamGroup *group = item;
    NSTableCellView *cellView = [outlineView makeViewWithIdentifier:GroupType owner:self];
    cellView.textField.stringValue = group.desc;
    
    return cellView;
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (_groups.count == 1)
    {
        // no outline necessary for a single group, just return parameters
        return _params.count;
    }
    
    if ([item isKindOfClass:OEShaderParamGroup.class])
    {
        OEShaderParamGroup *g = (OEShaderParamGroup *)item;
        return g.parameters.count;
    }
    
    return _groups.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (_groups.count == 1)
    {
        // no outline necessary for a single group, just return parameters
        return _params[index];
    }
    
    if ([item isKindOfClass:OEShaderParamGroup.class])
    {
        OEShaderParamGroup *g = (OEShaderParamGroup *)item;
        return g.parameters[index];
    }
    
    return _groups[index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if (_groups.count == 1) return NO;
    
    return [item isKindOfClass:OEShaderParamGroup.class];
}

@end

@implementation OEShaderParameter (View)

- (NSString *)selectCellType
{
    if (self.minimum == 0.0 && self.maximum == 1.0 && self.step == 1.0)
    {
        return CheckboxType;
    }
    return SliderType;
}

@end
