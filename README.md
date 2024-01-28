# Global Menu Library

The Global Menu Library is a versatile utility designed to streamline the creation and management of menus within Adobe AIR applications, offering a unified approach for both macOS (NativeApplication menus) and Windows (NativeWindow menus). This library abstracts the platform-specific differences, allowing developers to define menus in a consistent format across operating systems.

## Features
* __Unified Menu Definition__: Define menus using a JSON structure that is consistent across macOS and Windows.
* __Dynamic Menu Updates__: Easily enable/disable menu items and update labels on the fly, enhancing interactivity.
* __Event Handling__: Dispatch custom events upon menu item selection for seamless integration with application logic.

## Sample Client Code

```actionscript
import eu.claudiusiacob.desktop.GlobalMenu;
import eu.claudiusiacob.desktop.GlobalMenuEvent;

// Initialize GlobalMenu with JSON structure and application reference
var globalMenu:GlobalMenu = new GlobalMenu(jsonMenuStructure, NativeApplication.nativeApplication, "MyApp");

// Register main application window (Windows)
globalMenu.registerMainWindow(this.nativeWindow);

// Attach the menu to the application or window
globalMenu.attach();

// Listen for menu item selections
globalMenu.addEventListener(GlobalMenuEvent.ITEM_SELECT, function(event:GlobalMenuEvent):void {
trace("Menu item selected: " + event.cmdName);
});
```

## Public API Overview
* __GlobalMenu(jsonStructure, application, applicationName)__: Constructor to initialize the menu.
* __registerMainWindow(window)__: Registers the main application window, essential for menu attachment on Windows.
* __attach()__: Attaches the menu to the application (macOS) or the main window (Windows).
* __setItemEnablement(cmdName, state)__: Dynamically sets the enablement state of a menu item.
* __setItemLabel(cmdName, label)__: Updates the label of a menu item.
> Please note that dynamic updates to menu items (setItemEnablement, setItemLabel) may not take effect if a submenu is currently displayed. Ensure submenus are closed before making such updates.

This library aims to simplify menu management in cross-platform AIR applications, providing a clear and efficient way to handle native menus with minimal platform-specific code.