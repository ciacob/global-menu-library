package eu.claudiusiacob.desktop {
import flash.display.NativeMenu;

public class CustomNativeMenu extends NativeMenu {
    public var uid:int;

    override public function toString () : String {
        return ('NativeMenu #' + uid);
    }
}
}
