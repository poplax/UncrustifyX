//
//  UXAppDelegate.m
//  UncrustifyX
//
//  Created by Ryan Maxwell on 6/10/12.
//  Copyright (c) 2012 Ryan Maxwell. All rights reserved.
//

#import "UXAppDelegate.h"
#import "UXDataImporter.h"
#import "UXMainWindowController.h"
#import "UXPreferencesWindowController.h"
#import "UXDocumentationPanelController.h"

NSString *const UXErrorDomain                               = @"UXError";

@interface UXAppDelegate () <NSMenuDelegate>

@end

@implementation UXAppDelegate

#pragma mark - NSApplicationDelegate

+ (void)initialize {
    [super initialize];
    
    [UXDefaultsManager registerDefaults];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [MagicalRecord setupAutoMigratingCoreDataStack];
    [UXDataImporter importDefinitions];
    
    _mainWindowController = [[UXMainWindowController alloc] initWithWindowNibName:@"UXMainWindowController"];
    _mainWindowController.window.isVisible = YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [NSManagedObjectContext.defaultContext saveNestedContexts];
    [MagicalRecord cleanUp];
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
    
    for (NSString *filePath in filenames) {
        if ([filePath.pathExtension isEqualToString:@"cfg"]) {
            /* parse config */
            
            NSURL *fileURL = [NSURL fileURLWithPath:filePath];
            [self.mainWindowController importConfigurationAtURL:fileURL];
            
            [sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
            return;
        }
    }
    
    [self.mainWindowController addFilePaths:filenames];
    [sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (NSWindowController *)preferencesWindowController {
    if (!_preferencesWindowController) {
        _preferencesWindowController = [[UXPreferencesWindowController alloc] initWithWindowNibName:@"UXPreferencesWindowController"];
    }
    return _preferencesWindowController;
}

#pragma mark - IBAction

- (IBAction)importConfiguration:(id)sender {
    [self.mainWindowController importConfigurationPressed:sender];
}

- (IBAction)exportConfiguration:(id)sender {
    [self.mainWindowController exportConfigurationPressed:sender];
}

- (IBAction)showPreferences:(id)sender {
    self.preferencesWindowController.window.isVisible = YES;
    self.preferencesWindowController.window.level = 3; /* Documentation Panel Level */
    [self.preferencesWindowController.window makeKeyAndOrderFront:self];
}

- (IBAction)deletePressed:(id)sender {
    [self.mainWindowController deletePressed:sender];
}

- (IBAction)showView:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    
    switch (menuItem.tag) {
        case 1: {
            /* Files View */
            self.mainWindowController.toolbar.selectedItemIdentifier = self.mainWindowController.fileInputToolbarItem.itemIdentifier;
            [self.mainWindowController showView:self.mainWindowController.fileInputToolbarItem];
            break;
        }
            
        case 2: {
            /* Direct Input View */
            self.mainWindowController.toolbar.selectedItemIdentifier = self.mainWindowController.directInputToolbarItem.itemIdentifier;
            [self.mainWindowController showView:self.mainWindowController.directInputToolbarItem];
            break;
        }
        case 3: {
            /* Documentation */
            [self.mainWindowController toggleDocumentationPanel:self];
            break;
        }
    }
}

- (void)NSLogger {
#if TEST_CONSOLE_LOGGING
	LoggerSetOptions(NULL, kLoggerOption_LogToConsole);
#else
#if TEST_FILE_BUFFERING
	LoggerSetBufferFile(NULL, CFSTR("/tmp/NSLoggerTempData_MacOSX.rawnsloggerdata"));
#endif
#if TEST_DIRECT_CONNECTION
	LoggerSetViewerHost(NULL, LOGGING_HOST, LOGGING_PORT);
#endif
#endif
#if TEST_BONJOUR_SETUP
	// test restricting bonjour lookup for a specific machine
	LoggerSetupBonjour(NULL, NULL, CFSTR("Awesome"));
#endif
}

#pragma mark - NSMenuValidation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.tag == 11) {
        /* Export Configuration */
        return (self.mainWindowController.configOptions.count > 0);
    }
    return YES;
}

@end