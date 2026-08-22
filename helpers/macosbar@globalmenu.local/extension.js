import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

// Pull Spotlight (Search Light) next to Control Center (Quick Settings)
// and drop empty GNOME indicators that leave a hole in the right cluster.
const SPACER_ROLES = [
    'screenRecording',
    'screenSharing',
    'dwellClick',
    'a11y',
    'keyboard',
];

export default class MacosBarExtension extends Extension {
    enable() {
        this._hidden = [];
        this._power = null;
        this._searchMoved = null;

        this._hidePowerButton();
        this._hideSpacers();
        this._placeSearchBesideQuickSettings();
    }

    disable() {
        if (this._searchMoved) {
            let { actor, parent, index } = this._searchMoved;
            if (actor && parent) {
                let current = actor.get_parent();
                if (current)
                    current.remove_child(actor);
                let siblings = parent.get_children();
                if (index >= 0 && index < siblings.length)
                    parent.insert_child_at_index(actor, index);
                else
                    parent.add_child(actor);
            }
            this._searchMoved = null;
        }

        for (let actor of this._hidden)
            actor.show();
        this._hidden = [];

        if (this._power)
            this._power.show();
        this._power = null;
    }

    _hidePowerButton() {
        let qs = Main.panel.statusArea.quickSettings;
        let power = qs?._system || qs?._indicators?._system;
        if (!power && qs?._indicators?.get_children) {
            let children = qs._indicators.get_children();
            if (children.length)
                power = children[children.length - 1];
        }
        if (!power)
            return;
        power.hide();
        this._power = power;
    }

    _hideSpacers() {
        for (let role of SPACER_ROLES) {
            let item = Main.panel.statusArea[role];
            let actor = item?.container || item;
            if (actor?.hide) {
                actor.hide();
                this._hidden.push(actor);
            }
        }
    }

    _placeSearchBesideQuickSettings() {
        let right = Main.panel._rightBox;
        let qs = Main.panel.statusArea.quickSettings?.container;
        let search = this._findSearchIndicator(right);
        if (!right || !qs || !search || search === qs)
            return;

        let parent = search.get_parent();
        if (!parent)
            return;

        this._searchMoved = {
            actor: search,
            parent,
            index: parent.get_children().indexOf(search),
        };

        parent.remove_child(search);
        let qsIndex = right.get_children().indexOf(qs);
        if (qsIndex >= 0)
            right.insert_child_at_index(search, qsIndex);
        else
            right.add_child(search);
    }

    _findSearchIndicator(right) {
        if (!right?.get_children)
            return null;

        let known = new Set();
        let area = Main.panel.statusArea || {};
        for (let role of Object.keys(area)) {
            let container = area[role]?.container;
            if (container)
                known.add(container);
        }

        // Search Light inserts a raw St.Button, not via addToStatusArea.
        for (let child of right.get_children()) {
            if (!known.has(child))
                return child;
        }
        return null;
    }
}
