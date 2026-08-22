import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class MacosBarExtension extends Extension {
    enable() {
        this._power = this._findPowerIndicator();
        if (this._power) {
            this._power.hide();
            this._wasVisible = true;
        }
    }

    disable() {
        if (this._power && this._wasVisible)
            this._power.show();
        this._power = null;
        this._wasVisible = false;
    }

    _findPowerIndicator() {
        let qs = Main.panel.statusArea.quickSettings;
        if (!qs)
            return null;

        // GNOME 45+: SystemIndicator (power/battery) on the Quick Settings pill
        if (qs._system)
            return qs._system;
        if (qs._indicators?._system)
            return qs._indicators._system;

        let indicators = qs._indicators;
        if (indicators?.get_children) {
            let children = indicators.get_children();
            if (children.length)
                return children[children.length - 1];
        }
        return null;
    }
}
