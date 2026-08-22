import Gio from 'gi://Gio';
import St from 'gi://St';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from "resource:///org/gnome/shell/ui/main.js";
import { MenuManager } from './menuManager.js';
import { SystemMenuButton } from './systemMenu.js';

export default class GlobalMenuExtension extends Extension {
    constructor(metadata) {
        super(metadata);
        this._menuManager = null;
        this._settings = null;
        this._settingsChangedId = null;
        this._logoButton = null;
        this._overviewHidden = false;
        this._stylesheet = null;
        this._clockMoved = false;
        this._clockSessionBackup = null;
        this._powerHidden = null;
    }

    enable() {
        console.log(`[${this.metadata.uuid}] Enabling extension.`);

        this._settings = this.getSettings();

        const uuid = this.metadata.uuid || 'globalmenu@ShiroOSL.github.io';

        this._menuManager = new MenuManager(uuid, this._settings);

        const ICON_ONLY_KEYS = ['logo-icon-name', 'logo-custom-icon-path', 'logo-distro-icon', 'logo-distro-icon-symbolic', 'logo-icon-size'];

        this._settingsChangedId = this._settings.connect('changed', (_settings, key) => {
            if (key === 'hide-overview-button') {
                this._syncOverviewButton();
            } else if (key === 'show-logo-menu') {
                this._syncLogoButton();
            } else if (!ICON_ONLY_KEYS.includes(key)) {
                // Any other key (menu toggles, custom menus, indicator,
                // logo-menu item toggles) affects what the bar should show
                // right now. Icon-only keys are handled internally by
                // SystemMenuButton itself.
                this._syncMenuVisibility();
            }
        });

        global.display.connectObject('notify::focus-window', () => {
            this._syncMenuVisibility();
        }, this);

        this._loadStylesheet();
        Main.panel.add_style_class_name('globalmenu-macos-panel');
        this._moveClockToRight();
        this._hidePowerButton();

        this._syncLogoButton();
        this._syncOverviewButton();
        this._syncMenuVisibility();
    }

    // GNOME 42+ puts the clock in the center. macOS has it on the far
    // right, with speaker/network/etc immediately to its left.
    // Must update sessionMode.panel then _updatePanel(), otherwise Shell
    // restores the centered dateMenu on the next layout pass.
    _moveClockToRight() {
        let layout = Main.sessionMode?.panel;
        if (!layout) {
            this._moveClockFallback();
            return;
        }

        this._clockSessionBackup = {
            left: layout.left.slice(),
            center: layout.center.slice(),
            right: layout.right.slice(),
        };

        layout.center = layout.center.filter(item => item !== 'dateMenu');
        layout.right = layout.right.filter(item => item !== 'dateMenu');
        layout.right.push('dateMenu');
        Main.panel._updatePanel();
        this._clockMoved = true;
        console.log(`[globalmenu] Clock moved to right. panel.right=${layout.right.join(',')}`);
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
        this._powerHidden = power;
    }

    _showPowerButton() {
        if (this._powerHidden)
            this._powerHidden.show();
        this._powerHidden = null;
    }

    _moveClockFallback() {
        let dateMenu = Main.panel.statusArea.dateMenu;
        if (!dateMenu?.container)
            return;

        let container = dateMenu.container;
        let parent = container.get_parent();
        if (!parent)
            return;

        parent.remove_child(container);
        Main.panel._rightBox.add_child(container);
        this._clockMoved = true;
    }

    _restoreClock() {
        if (!this._clockMoved)
            return;

        let layout = Main.sessionMode?.panel;
        if (layout && this._clockSessionBackup) {
            layout.left = this._clockSessionBackup.left.slice();
            layout.center = this._clockSessionBackup.center.slice();
            layout.right = this._clockSessionBackup.right.slice();
            Main.panel._updatePanel();
        } else {
            let dateMenu = Main.panel.statusArea.dateMenu;
            let container = dateMenu?.container;
            if (container) {
                let parent = container.get_parent();
                if (parent)
                    parent.remove_child(container);
                Main.panel._centerBox.add_child(container);
            }
        }

        this._clockMoved = false;
        this._clockSessionBackup = null;
    }

    _loadStylesheet() {
        let cssFile = Gio.File.new_for_path(`${this.path}/stylesheet.css`);
        if (!cssFile.query_exists(null))
            return;
        let themeContext = St.ThemeContext.get_for_stage(global.stage);
        this._stylesheet = themeContext.get_theme().load_stylesheet(cssFile);
    }

    _unloadStylesheet() {
        if (!this._stylesheet)
            return;
        let themeContext = St.ThemeContext.get_for_stage(global.stage);
        themeContext.get_theme().unload_stylesheet(this._stylesheet);
        this._stylesheet = null;
    }

    _syncLogoButton() {
        let shouldShow = this._settings.get_boolean('show-logo-menu');

        if (shouldShow && !this._logoButton) {
            // A previous failed enable() can leave this role occupied.
            let existing = Main.panel.statusArea['globalmenu-logo'];
            if (existing)
                existing.destroy();
            this._logoButton = new SystemMenuButton(this._settings, this.path);
            Main.panel.addToStatusArea('globalmenu-logo', this._logoButton, 0, 'left');
        } else if (!shouldShow && this._logoButton) {
            this._logoButton.destroy();
            this._logoButton = null;
        }
    }

    _syncOverviewButton() {
        let activities = Main.panel.statusArea['activities'];
        if (!activities) return;

        let shouldHide = this._settings.get_boolean('hide-overview-button');
        if (shouldHide && !this._overviewHidden) {
            activities.hide();
            this._overviewHidden = true;
        } else if (!shouldHide && this._overviewHidden) {
            activities.show();
            this._overviewHidden = false;
        }
    }

    _syncMenuVisibility() {
        if (!this._menuManager) return;

        if (this._settings.get_boolean('show-indicator')) {
            let activeWindow = global.display.get_focus_window();
            this._menuManager.updateMenuForWindow(activeWindow);
        } else {
            this._menuManager.clear();
        }
    }

    disable() {
        console.log(`[globalmenu@ShiroOSL.github.io] Disabling extension.`);

        global.display.disconnectObject(this);

        if (this._settings && this._settingsChangedId) {
            this._settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = null;
        }

        if (this._menuManager) {
            this._menuManager.destroy();
            this._menuManager = null;
        }

        if (this._logoButton) {
            this._logoButton.destroy();
            this._logoButton = null;
        }

        if (this._overviewHidden) {
            let activities = Main.panel.statusArea['activities'];
            if (activities) activities.show();
            this._overviewHidden = false;
        }

        this._restoreClock();
        this._showPowerButton();
        Main.panel.remove_style_class_name('globalmenu-macos-panel');
        this._unloadStylesheet();

        this._settings = null;
    }
}
