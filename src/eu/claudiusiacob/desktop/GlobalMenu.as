package eu.claudiusiacob.desktop {
import flash.desktop.NativeApplication;
import flash.display.NativeMenu;
import flash.display.NativeMenuItem;
import flash.display.NativeWindow;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.IEventDispatcher;
import flash.ui.Keyboard;

public class GlobalMenu implements IEventDispatcher {

    public function GlobalMenu(
            jsonStructure:String,
            application:NativeApplication,
            applicationName : String = null
    ) {
        _dispatcher = new EventDispatcher(this);
        _jsonStructure = jsonStructure;
        _application = application;
        _applicationName = applicationName;
        _os = _getOs();
        _menu = _parseMenuJson(this._jsonStructure);
    }

    private var _dispatcher:EventDispatcher;
    private var _jsonStructure:String;
    private var _application:NativeApplication;
    private var _applicationName:String;
    private var _mainWindow:NativeWindow;
    private var _menu:NativeMenu;
    private var _os:String;

    // Implement IEventDispatcher interface methods by delegating to the dispatcher instance
    public function dispatchEvent(event:Event):Boolean {
        return _dispatcher.dispatchEvent(event);
    }

    public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void {
        _dispatcher.addEventListener(type, listener, useCapture, priority, useWeakReference);
    }

    public function hasEventListener(type:String):Boolean {
        return _dispatcher.hasEventListener(type);
    }

    public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void {
        _dispatcher.removeEventListener(type, listener, useCapture);
    }

    public function willTrigger(type:String):Boolean {
        return _dispatcher.willTrigger(type);
    }

    public function registerMainWindow(window:NativeWindow):void {
        if (_mainWindow != null) {
            return;
        }
        _mainWindow = window;
    }

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

    private function _getOs():String {
        return NativeApplication.supportsMenu ? 'mac' :
                NativeWindow.supportsMenu ? 'win' : 'other';
    }

    private function _attachMacMenu():void {
        _application.menu = _menu;
    }

    private function _attachWinMenu():void {
        _mainWindow.menu = _menu;
    }

     private function _parseMenuJson(json:String):NativeMenu {
        var rawMenuData:Object = JSON.parse(json);
        if (_os == 'mac') {
            rawMenuData = _convertToMacFormat(rawMenuData);
        }
        return _buildNativeMenu(rawMenuData.menu as Array);
    }

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
                    case "command":
                        result.keyEquivalentModifiers.push(Keyboard.COMMAND);
                        break;
                    case "shift":
                        result.keyEquivalentModifiers.push(Keyboard.SHIFT);
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

    private function _buildNativeMenu(menuStructure:Array):NativeMenu {
        var menu:NativeMenu = new NativeMenu();
        for each (var itemData:Object in menuStructure) {
            var menuItem:NativeMenuItem;
            if (itemData.isSeparator) {
                menuItem = new NativeMenuItem("", true);
            } else {
                menuItem = new NativeMenuItem(_cloakLabel(itemData.label));
                if (itemData.hasOwnProperty("cmdName")) {
                    menuItem.name = itemData.cmdName;
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
                if (itemData.hasOwnProperty("children")) {
                    menuItem.submenu = _buildNativeMenu(itemData.children);
                }
            }
            menu.addItem(menuItem);
        }
        return menu;
    }

    private function _onItemSelected(event:Event):void {
        var menuItem:NativeMenuItem = NativeMenuItem(event.currentTarget);
        dispatchEvent(new GlobalMenuEvent(GlobalMenuEvent.ITEM_SELECT, menuItem.name));
    }

    private function _cloakLabel(label:String):String {
        if (label.length > 0) {
            return label.charAt(0) + "\u200B" + label.slice(1);
        }
        return label;
    }

    private function _convertToMacFormat(menuStructure:Object):Object {
        if (!_applicationName) {
            return menuStructure;
        }

        // Create the "Home" menu
        var homeMenu:Object = { "label": _cloakLabel(_applicationName), "children": [] };

        // Unshift top-level menus by one
        menuStructure.menu.unshift(homeMenu);

        // Call recursive function to fetch "isHomeItem" items
        _fetchHomeItems(menuStructure.menu, homeMenu.children);

        return menuStructure;
    }

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
}
}
