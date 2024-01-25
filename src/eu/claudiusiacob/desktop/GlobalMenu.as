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

    private var dispatcher:EventDispatcher;
    private var _initialJson1:String;
    private var _application:NativeApplication;
    private var _mainWindow:NativeWindow;
    private var _menu:NativeMenu;
    private var _currOs:String;
    private var _debugShortcuts:Boolean;

    public function GlobalMenu(
            initialJson:String,
            application:NativeApplication,
            mainWindow:NativeWindow = null,
            debugShortcuts:Boolean = false
    ) {
        dispatcher = new EventDispatcher(this);
        _initialJson1 = initialJson;
        _application = application;
        _mainWindow = mainWindow;
        _debugShortcuts = debugShortcuts;
        _currOs = determineOS();
        _menu = parseMenuJson(this._initialJson1);

        switch (_currOs) {
            case 'mac':
                createMacOSMenu();
                break;
            case 'win':
                // If we have a main window already, attach the menu to it.
                // Otherwise, we get another chance when `registerMainWindow()`
                // is called.
                if (_mainWindow != null) {
                    createWindowsMenu();
                }
                break;
            default:
                // Maybe we'll do something here in the future.
                break;
        }
    }

// Implement IEventDispatcher interface methods by delegating to the dispatcher instance
    public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void {
        dispatcher.addEventListener(type, listener, useCapture, priority, useWeakReference);
    }

    public function dispatchEvent(event:Event):Boolean {
        return dispatcher.dispatchEvent(event);
    }

    public function hasEventListener(type:String):Boolean {
        return dispatcher.hasEventListener(type);
    }

    public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void {
        dispatcher.removeEventListener(type, listener, useCapture);
    }

    public function willTrigger(type:String):Boolean {
        return dispatcher.willTrigger(type);
    }

    // Function to handle menu item selection
    private function onMenuItemSelect(cmdName:String):void {
        dispatchEvent(new GlobalMenuEvent(GlobalMenuEvent.ITEM_SELECT, cmdName));
    }

    public function registerMainWindow(window:NativeWindow):void {
        if (_mainWindow != null) {
            return;
        }
        _mainWindow = window;
        if (_mainWindow != null && _currOs == 'win') {
            createWindowsMenu();
        }
    }

    private function determineOS():String {
        return NativeApplication.supportsMenu ? 'mac' :
                NativeWindow.supportsMenu ? 'win' : 'other';
    }

    private function createMacOSMenu():void {
        _application.menu = _menu;
    }

    private function createWindowsMenu():void {
        _mainWindow.menu = _menu;
    }

    private function mapKeyShortcuts(shortcuts:Array):Object {
        var result:Object = {
            keyEquivalent: "",
            keyEquivalentModifiers: []
        };
        if (shortcuts.length > 0) {
            result.keyEquivalent = shortcuts.pop();
            for each (var key:String in shortcuts) {
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

    private function parseMenuJson(json:String):NativeMenu {
        var data:Object = JSON.parse(json);
        return createMenuFromObject(data.menu as Array);
    }

    private function parseKeyboardShortcuts(kbShortcuts:Object):Object {
        var shortcuts:Array;
        if (kbShortcuts is Array) {
            // Direct array implies OS-agnostic shortcut
            shortcuts = kbShortcuts as Array;
        } else if (kbShortcuts.hasOwnProperty(_currOs)) {
            // Object with OS-specific keys
            shortcuts = kbShortcuts[_currOs];
        }

        if (shortcuts) {
            return mapKeyShortcuts(shortcuts);
        }
        return null;
    }

    private function createMenuFromObject(menuData:Array):NativeMenu {
        var menu:NativeMenu = new NativeMenu();
        for each (var itemData:Object in menuData) {
            var menuItem:NativeMenuItem;
            if (itemData.isSeparator) {
                menuItem = new NativeMenuItem("", true);
            } else {
                menuItem = new NativeMenuItem(itemData.label);
                if (itemData.hasOwnProperty("cmdName")) {
                    menuItem.name = itemData.cmdName;
                    menuItem.addEventListener(Event.SELECT, menuItemSelectHandler);
                }
                if (itemData.hasOwnProperty("disabled")) {
                    menuItem.enabled = !itemData.disabled;
                }
                if (itemData.hasOwnProperty("isChecked")) {
                    menuItem.checked = itemData.isChecked;
                }
                if (itemData.hasOwnProperty("kbShortcuts")) {
                    var shortcutObj:Object = parseKeyboardShortcuts(itemData.kbShortcuts);
                    if (shortcutObj) {
                        menuItem.keyEquivalent = shortcutObj.keyEquivalent;
                        menuItem.keyEquivalentModifiers = shortcutObj.keyEquivalentModifiers;
                        if (_debugShortcuts) {
                            menuItem.label += "    [" + _spellOutShortcut(shortcutObj) + "]";
                        }
                    }
                }
                if (itemData.hasOwnProperty("children")) {
                    menuItem.submenu = createMenuFromObject(itemData.children);
                }
            }
            menu.addItem(menuItem);
        }
        return menu;
    }

    private function menuItemSelectHandler(event:Event):void {
        var menuItem:NativeMenuItem = NativeMenuItem(event.currentTarget);
        dispatchEvent(new GlobalMenuEvent(GlobalMenuEvent.ITEM_SELECT, menuItem.name));
    }

    private function _spellOutShortcut(shortcutData:Object):String {
        var keyEquivalent:String = shortcutData.keyEquivalent;
        var keyModifiers:Array = shortcutData.keyEquivalentModifiers;
        var shortcutStr:String = "";

        // Iterate through keyModifiers array
        for each (var modKey:uint in keyModifiers) {
            switch (modKey) {
                case Keyboard.CONTROL:
                    shortcutStr += "CTRL+";
                    break;
                case Keyboard.COMMAND:
                    shortcutStr += "CMD+";
                    break;
                case Keyboard.ALTERNATE:
                    shortcutStr += "ALT+";
                    break;
                case Keyboard.SHIFT:
                    // Prevent duplicating "SHIFT+" if it's inferred from uppercase keyEquivalent
                    if (!(keyEquivalent.toUpperCase() == keyEquivalent && keyEquivalent.length == 1)) {
                        shortcutStr += "SHIFT+";
                    }
                    break;
                    // Add other cases as necessary
            }
        }
        shortcutStr += keyEquivalent.toUpperCase();
        return shortcutStr;
    }


    public function setStructure(str:Object):void {
        // TO ASSESS the need of.
    }
}
}
