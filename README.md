# Global Menu Library

The Global Menu Library is a versatile utility designed to streamline the creation and management of menus within Adobe AIR applications, offering a unified approach for both macOS (NativeApplication menus) and Windows (NativeWindow menus). This library abstracts the platform-specific differences, allowing developers to define menus in a consistent format across operating systems.

## Features
* __Unified Menu Definition__: Define menus using a JSON/Object structure that is consistent across macOS and Windows.
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

To build the menu in its initial form, you must provide a JSON String (or equivalent Object) that resembles to the following:

```json
{
  "menu":[
    {
      "label":"File",
      "children":[
        {
          "label":"New...",
          "cmdName":"cmd_new_project",
          "kbShortcuts": [
            "alt",
            "n"
          ]
        },
        {
          "isSeparator":true
        },
        {
          "label":"Save",
          "cmdName":"cmd_save_project",
          "kbShortcuts":{
            "win":[
              "ctrl",
              "s"
            ],
            "mac":[
              "cmd",
              "s"
            ]
          }
        },
        {
          "label":"Save to Cloud (PRO Feature)",
          "cmdName":"cmd_cloud_save_project",
          "disabled":"true"
        },
        {
          "isSeparator":true
        },        {
          "label":"About MyApp 123...",
          "cmdName":"cmd_about_app",
          "isHomeItem": true
        }
      ]
    },
    {
      "label":"View",
      "children":[
        {
          "label":"Theme",
          "children":[
            {
              "label":"Light",
              "cmdName":"cmd_set_theme_light",
              "isChecked":true
            },
            {
              "label":"Dark",
              "cmdName":"cmd_set_theme_dark",
              "isChecked":false
            }
          ]
        }
      ]
    }
  ]
}
```

Mind a couple of things:
* There is no _home menu_ defined in the JSON. That menu is dynamically built on macOS based on the provided __applicationName__ constructor argument (see the __Public API overview__, next) and the `isHomeItem` tag. Essentially, all menu items that are tagged as `isHomeItem` in the JSON are collected and displayed underneath the _home menu_, while on macOS. On Windows, they remain underneath their original menu. If no item is marked as `isHomeItem` in the JSON, the _home menu_ will be empty on macOS. If you don't provide the optional __applicationName__ constructor argument, there will be no home menu (which might confuse Mac users, beware).
* Only items having a `cmdName` set are _actionable_, i.e., you can _do_ something in response to the user selecting them via mouse or the keyboard. If you want to receive a `GlobalMenuEvent` for a specific item in the menu, make sure you give that item a `cmdName`. The received event will make that accessible via its `cmdName` property.
* There are two ways of defining keyboard shortcuts in the JSON:
  1.  `"kbShortcuts" : [ "modifier1", "modifierN", "key" ]`
  2. `"kbShortcuts" : { "win": [ "modifier1", "modifierN", "key" ], "mac": [ "modifier1", "modifierN", "key" ] }`

  In the first case, the same shortcut is registered on both Windows and macOS; in the second, the `win` and `mac` keys determine what to register, based on the current operating system. Note that you need not use both `win` and `mac`: if you want to have items that only have keyboard shortcuts on _one_ operating system, just leave out the other key.

  For __modifier1 ... modifierN__ use one of `ctrl`, `cmd` and/or `alt`. The presence of the `SHIFT` key is implied by the casing of `key`, e.g., `["alt", "s"]` means __ALT+S__, whereas `["alt", "S"]` means __SHIFT+ALT+S__. 
> __Notes__:
> * Due to original Adobe design of the `NativeMenuItem` class, you can only use printable chars as the `key` part of a shortcut.
> * You can leave out the __modifier1 ... modifierN__ part altogether, e.g.: `"kbShortcuts" : [ "o" ]` sets the key __O__ by itself as the keyboard shortcut a menu item will use.

## Public API Overview
* __GlobalMenu(structure, application, applicationName)__: Constructor to initialize the menu.
* __registerMainWindow(window)__: Registers the main application window, essential for menu attachment on Windows.
* __attach()__: Attaches the menu to the application (macOS) or the main window (Windows).
* __setItemEnablement(cmdName, state)__: Dynamically sets the enablement state of a menu item.
* __setItemLabel(cmdName, label)__: Updates the label of a menu item.
> Please note that dynamic updates to menu items (setItemEnablement, setItemLabel) may not take effect if a submenu is currently displayed. Ensure submenus are closed before making such updates.

This library aims to simplify menu management in cross-platform AIR applications, providing a clear and efficient way to handle native menus with minimal platform-specific code.