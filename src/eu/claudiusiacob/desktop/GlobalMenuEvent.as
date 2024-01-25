package eu.claudiusiacob.desktop {
import flash.events.Event;

public class GlobalMenuEvent extends Event {
    public static const ITEM_SELECT:String = "itemSelect";
    public var cmdName:String;

    public function GlobalMenuEvent(type:String, cmdName:String, bubbles:Boolean = false, cancelable:Boolean = false) {
        super(type, false, true);
        this.cmdName = cmdName;
    }

    override public function clone():Event {
        return new GlobalMenuEvent(type, this.cmdName, bubbles, cancelable);
    }
}

}
