package eu.claudiusiacob.desktop {
import flash.desktop.NativeApplication;
import flash.display.NativeMenuItem;
import flash.display.NativeWindow;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.IEventDispatcher;
import flash.ui.Keyboard;

/**
 * The GlobalMenu class manages the creation and attachment of a native menu for Adobe AIR applications,
 * with specific adaptations for macOS and Windows platforms. It supports dynamic menu creation based on a JSON structure,
 * handling of keyboard shortcuts, and dispatching events on menu item selection.
 *
 * @param jsonStructure JSON string defining the menu structure.
 * @param application Reference to the NativeApplication.
 * @param applicationName Optional name of the application, used for the macOS app menu.
 */
public class GlobalMenu implements IEventDispatcher {

    private static const ENABLEMENT_CHANGE:String = 'ENABLEMENT_CHANGE';
    private static const LABEL_CHANGE:String = 'LABEL_CHANGE';

    /**
     * The GlobalMenu class manages the creation and attachment of a native menu for Adobe AIR applications,
     * with specific adaptations for macOS and Windows platforms. It supports dynamic menu creation based on a JSON structure,
     * handling of keyboard shortcuts, and dispatching events on menu item selection.
     *
     * @param structure Object or valid JSON string defining the menu structure.
     * @param application Reference to the NativeApplication.
     * @param applicationName Optional name of the application, used for the macOS app menu.
     */
    public function GlobalMenu(
            structure:Object,
            application:NativeApplication,
            applicationName:String = null
    ) {
        _dispatcher = new EventDispatcher(this);
        _application = application;
        _applicationName = applicationName;
        _os = _getOs();

        // Determine the type of `structure` sent it, and handle accordingly.
        if (structure is String) {
            try {
                _rawMenuData = (JSON.parse(structure as String)).menu;
            } catch(e:Error) {
                throw new ArgumentError('GlobalMenu: failed to parse given `structure` argument as JSON.\n' + e);
            }
        } else if (structure is Object) {
            _rawMenuData = structure.menu;
        } else {
            throw new ArgumentError('GlobalMenu: given `structure` argument must be a JSON String or an Object; ' + (typeof structure) + ' given.');
        }
        _menu = _makeMenu(_rawMenuData);
    }

    private var _dispatcher:EventDispatcher;
    private var _application:NativeApplication;
    private var _applicationName:String;
    private var _mainWindow:NativeWindow;
    private var _rawMenuData : Object;
    private var _menu:CustomNativeMenu;
    private var _os:String;
    private var _actionableItems:Object = {};
    private var _menusByIndex:Object = {};
    private var _menusCounter:int = 0;
    private var _scheduledChanges:Object = {};
    private var _menuItemsById:Object = {};

    /*
    @see EventDispatcher#addEventListener
     */
    public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void {
        _dispatcher.addEventListener(type, listener, useCapture, priority, useWeakReference);
    }

    /*
    @see EventDispatcher#hasEventListener
     */
    public function hasEventListener(type:String):Boolean {
        return _dispatcher.hasEventListener(type);
    }

    /*
    @see EventDispatcher#removeEventListener
     */
    public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void {
        _dispatcher.removeEventListener(type, listener, useCapture);
    }

    /*
    @see EventDispatcher#willTrigger
     */
    public function willTrigger(type:String):Boolean {
        return _dispatcher.willTrigger(type);
    }

    /**
     * Registers the main application window to which the menu will be attached on Windows platforms.
     *
     * @param window The main application window.
     */
    public function registerMainWindow(window:NativeWindow):void {
        if (_mainWindow != null) {
            return;
        }
        _mainWindow = window;
    }

    /**
     * Attaches the constructed menu to the application or window, based on the operating system.
     * For macOS, attaches to the application menu; for Windows, attaches to the registered main window.
     */
    public function attach():void {
        switch (_os) {
            case 'mac':
                _attachMacMenu();
                break;
            case 'win':
                // If we have a main window already, attach the menu to it.
                if (!_mainWindow) {
                    throw ('No valid main window was registered. Cannot attach menu to `' + _mainWindow + '`.');
                }
                _attachWinMenu();
                break;
            default:
                // Maybe we'll do something here in the future.
                break;
        }
    }

    /**
     * Sets the enablement state of a menu item identified by its command name. Note: This method may not apply changes
     * while any submenu is displayed. Ensure all submenus are closed before calling.
     *
     * @param cmdName The command name of the menu item whose enablement state is to be set.
     * @param state The enablement state to set for the menu item (true for enabled, false for disabled).
     */
    public function setItemEnablement(cmdName:String, state:Boolean):void {
        if (_actionableItems.hasOwnProperty(cmdName)) {
            _scheduleItemChange(cmdName, ENABLEMENT_CHANGE, [state]);
        }
    }

    /**
     * Sets the label of a menu item identified by its command name. Note: This method may not apply changes
     * while any submenu is displayed. Ensure all submenus are closed before calling.
     *
     * @param cmdName The command name of the menu item whose label is to be updated.
     * @param label The new label for the menu item.
     */
    public function setItemLabel(cmdName:String, label:String):void {
        if (_actionableItems.hasOwnProperty(cmdName)) {
            _scheduleItemChange(cmdName, LABEL_CHANGE, [label]);
        }
    }

    /**
     * Sets the checked state of a menu item identified by its id. This method allows dynamic updates to the menu item's state, reflecting changes in the application's state or user's choices.
     *
     * @param id The unique identifier for the menu item whose checked state is to be updated.
     * @param checked The new checked state for the menu item (true for checked, false for unchecked).
     */
    public function setItemChecked(id:String, checked:Boolean):void {
        var menuItem:NativeMenuItem = _getMenuItemById(id);
        if (menuItem) {
            menuItem.checked = checked;
        }
    }

    /**
     * Retrieves a NativeMenuItem instance by its unique identifier. This method supports accessing menu items directly, facilitating operations like updating their properties at runtime.
     *
     * @param id The unique identifier of the menu item to retrieve.
     * @return The NativeMenuItem instance associated with the given id, or null if no such item exists.
     */
    private function _getMenuItemById(id:String):NativeMenuItem {
        return _menuItemsById[id];
    }

    /**
     * Identifies the operating system and returns a string indicating the OS ('mac', 'win', or 'other').
     *
     * @return A string representing the operating system.
     */
    private function _getOs():String {
        return NativeApplication.supportsMenu ? 'mac' :
                NativeWindow.supportsMenu ? 'win' : 'other';
    }

    /**
     * Attaches the menu to the application for macOS. This method is called internally when attach() is invoked on macOS.
     */
    private function _attachMacMenu():void {
        _application.menu = _menu;
    }

    /**
     * Attaches the menu to the main window for Windows. This method is called internally when attach() is invoked on Windows,
     * and a main window has been registered.
     */
    private function _attachWinMenu():void {
        _mainWindow.menu = _menu;
    }

    /**
     * Schedule a change for an item in the menu.
     *
     * @param {String} itemCmdName - The command name of the item to be changed.
     * @param {String} changeType - The type of change to be made.
     * @param {Array} changeArgs - The arguments for the change.
     *
     * @return {void}
     */
    private function _scheduleItemChange(itemCmdName:String, changeType:String, changeArgs:Array):void {
        if (_actionableItems.hasOwnProperty(itemCmdName)) {
            var menuItem:NativeMenuItem = _actionableItems[itemCmdName];
            var menu:CustomNativeMenu = (menuItem.menu as CustomNativeMenu);
            var menuId:int = menu.uid;
            if (!(menuId in _scheduledChanges)) {
                _scheduledChanges[menuId] = {};
                menu.addEventListener(Event.DISPLAYING, _onMenuAboutToShow);
            }
            _scheduledChanges[menuId][itemCmdName] = {"changeType": changeType, "changeArgs": changeArgs};
        }
    }

    /**
     * Converts given `rawMenuData` to a CustomNativeMenu object. This method also adapts
     * the menu for macOS by calling _convertToMacFormat if necessary.
     *
     * @param rawMenuData The Object defining the menu structure.
     * @return The constructed CustomNativeMenu object.
     */
    private function _makeMenu(rawMenuData:Object):CustomNativeMenu {
        if (_os == 'mac') {
            rawMenuData = _convertToMacFormat(rawMenuData);
        }
        return _buildNativeMenu(rawMenuData as Array);
    }

    /**
     * Analyzes the keyboard shortcut definition from the menu structure, accommodating both OS-agnostic and OS-specific formats.
     *
     * @param rawShortcutSrc The source object for the keyboard shortcut, which can be an Array or an Object.
     * @return An Object containing the parsed keyEquivalent and keyEquivalentModifiers.
     */
    private function _getShortcutDefinition(rawShortcutSrc:Object):Object {
        var shortcutElements:Array;
        if (rawShortcutSrc is Array) {
            // Direct array implies OS-agnostic shortcut
            shortcutElements = rawShortcutSrc as Array;
        } else if (rawShortcutSrc.hasOwnProperty(_os)) {
            // Object with OS-specific keys
            shortcutElements = rawShortcutSrc[_os];
        }

        if (shortcutElements) {
            return _parseShortcutDefinition(shortcutElements);
        }
        return null;
    }

    /**
     * Processes an array of shortcut elements to construct a keyboard shortcut definition, including the key equivalent and
     * any modifier keys.
     *
     * @param shortcutElements An array containing the key equivalent and modifier keys.
     * @return An Object containing the keyEquivalent and keyEquivalentModifiers for the shortcut.
     */
    private function _parseShortcutDefinition(shortcutElements:Array):Object {
        var result:Object = {
            keyEquivalent: "",
            keyEquivalentModifiers: []
        };
        if (shortcutElements.length > 0) {
            result.keyEquivalent = shortcutElements.pop();
            for each (var key:String in shortcutElements) {
                switch (key.toLowerCase()) {
                    case "ctrl":
                        result.keyEquivalentModifiers.push(Keyboard.CONTROL);
                        break;
                    case "cmd":
                        result.keyEquivalentModifiers.push(Keyboard.COMMAND);
                        break;
                    case "alt":
                        result.keyEquivalentModifiers.push(Keyboard.ALTERNATE);
                        break;
                        // Add other cases as necessary
                }
            }
        }
        return result;
    }

    /**
     * Recursively builds a CustomNativeMenu from a structured Array representing the menu items. This method handles the creation
     * of menu items, including separators, submenus, and the assignment of keyboard shortcuts and event listeners.
     *
     * @param menuStructure An Array of Objects representing the menu and its items.
     * @return The constructed CustomNativeMenu.
     */
    private function _buildNativeMenu(menuStructure:Array):CustomNativeMenu {
        var menu:CustomNativeMenu = new CustomNativeMenu();
        _registerMenu(menu);
        for each (var itemData:Object in menuStructure) {
            var menuItem:NativeMenuItem;
            if (itemData.isSeparator) {
                menuItem = new NativeMenuItem("", true);
            } else {
                menuItem = new NativeMenuItem(_cloakLabel(itemData.label));
                if (itemData.hasOwnProperty("cmdName")) {
                    menuItem.name = itemData.cmdName;
                    _actionableItems[itemData.cmdName] = menuItem;
                    menuItem.addEventListener(Event.SELECT, _onItemSelected);
                }
                if (itemData.hasOwnProperty("disabled")) {
                    menuItem.enabled = !itemData.disabled;
                }
                if (itemData.hasOwnProperty("isChecked")) {
                    menuItem.checked = itemData.isChecked;
                }
                if (itemData.hasOwnProperty("kbShortcuts")) {
                    var shortcutObj:Object = _getShortcutDefinition(itemData.kbShortcuts);
                    if (shortcutObj) {
                        menuItem.keyEquivalent = shortcutObj.keyEquivalent;
                        menuItem.keyEquivalentModifiers = shortcutObj.keyEquivalentModifiers;
                    }
                }
                if (itemData.hasOwnProperty("id")) {
                    _menuItemsById[itemData.id] = menuItem;
                }
                if (itemData.hasOwnProperty("children")) {
                    menuItem.submenu = _buildNativeMenu(itemData.children);
                }
            }
            menu.addItem(menuItem);
        }
        return menu;
    }

    /**
     * "Registers" a custom menu, essentially making sure that it will be retrievable
     * by its unique id, in the future.
     *
     * @param {CustomNativeMenu} menu - The menu object to be registered.
     */
    private function _registerMenu(menu:CustomNativeMenu):void {
        var menuIndex:int = (++_menusCounter);
        menu.uid = menuIndex;
        _menusByIndex[menuIndex] = menu;
    }

    /**
     * Modifies a menu label to include a zero-width space, used to prevent automatic menu item additions by macOS.
     *
     * @param label The original menu item label.
     * @return The modified label with a zero-width space inserted.
     */
    private function _cloakLabel(label:String):String {
        if (label.length > 0) {
            return label.charAt(0) + "\u200B" + label.slice(1);
        }
        return label;
    }

    /**
     * Adapts the menu structure for macOS by creating a "Home" menu with the application name and moving items marked with `isHomeItem`.
     *
     * @param menuStructure The original menu structure object.
     * @return The adapted menu structure for macOS.
     */
    private function _convertToMacFormat(menuStructure:Object):Object {
        if (!_applicationName) {
            return menuStructure;
        }

        // Create the "Home" menu
        var homeMenu:Object = {"label": _cloakLabel(_applicationName), "children": []};

        // Unshift top-level menus by one
        menuStructure.menu.unshift(homeMenu);

        // Call recursive function to fetch "isHomeItem" items
        _fetchHomeItems(menuStructure.menu, homeMenu.children);

        return menuStructure;
    }

    /**
     * Recursively searches through the menu structure to find and move items marked as `isHomeItem` to the "Home" menu.
     *
     * @param menuArray The array of menu items to search through.
     * @param homeItems The array to which items marked as `isHomeItem` should be moved.
     */
    private function _fetchHomeItems(menuArray:Array, homeItems:Array):void {
        for (var i:int = menuArray.length - 1; i >= 0; i--) {
            var item:Object = menuArray[i];
            if (item.hasOwnProperty("isHomeItem") && item.isHomeItem) {
                homeItems.push(item);
                menuArray.splice(i, 1); // Remove from original position
            } else if (item.hasOwnProperty("children")) {
                _fetchHomeItems(item.children, homeItems);
            }
        }
    }

    /*
    @see EventDispatcher#dispatchEvent
     */
    public function dispatchEvent(event:Event):Boolean {
        return _dispatcher.dispatchEvent(event);
    }

    /**
     * Handles the selection of a menu item by dispatching a GlobalMenuEvent with the cmdName of the selected item.
     *
     * @param event The event object associated with the menu item selection.
     */
    private function _onItemSelected(event:Event):void {
        var menuItem:NativeMenuItem = NativeMenuItem(event.currentTarget);
        dispatchEvent(new GlobalMenuEvent(GlobalMenuEvent.ITEM_SELECT, menuItem.name));
    }

    /**
     * Handles the `Event.DISPLAYING` event for a native menu.
     *
     * Applies scheduled modifications such as label changing and enablement state adjustments to menu items, as
     * stored in the `_scheduledChanges` registry. These changes take effect immediately before the parent menu is
     * displayed. After applying the changes, clears up scheduling, and detaches the handler to safeguard against
     * potential, future memory leaks.
     *
     * @param event The event object containing reference to the menu about to be displayed.
     */
    private function _onMenuAboutToShow(event:Event):void {
        var menu:CustomNativeMenu = (event.target as CustomNativeMenu);
        var menuChanges:Object = (_scheduledChanges[menu.uid] as Object);
        for (var cmdName:String in menuChanges) {
            var changeDetails:Object = (menuChanges[cmdName] as Object);
            var changeType:String = changeDetails.changeType;
            var changeArgs:Array = changeDetails.changeArgs;
            var targetMenuItem:NativeMenuItem = (_actionableItems[cmdName] as NativeMenuItem);
            switch (changeType) {
                case ENABLEMENT_CHANGE:
                    targetMenuItem.enabled = (changeArgs[0] as Boolean);
                    break;
                case LABEL_CHANGE:
                    targetMenuItem.label = _cloakLabel(changeArgs[0] as String);
                    break;
            }
        }
        _scheduledChanges[menu.uid] = null;
        delete (_scheduledChanges[menu.uid]);
        menu.removeEventListener(Event.DISPLAYING, _onMenuAboutToShow);
    }
}
}
