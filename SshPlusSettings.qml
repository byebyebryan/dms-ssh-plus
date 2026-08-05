import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "sshPlus"

    StyledText {
        width: parent.width
        text: "SSH Plus"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "SSH from the launcher and remember hosts that connect successfully. Recorded hosts and their connection stats live in the plugin state file, separate from these settings."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "trigger"
        label: "Trigger Prefix"
        placeholder: "ssh:"
        defaultValue: "ssh:"
    }

    StringSetting {
        settingKey: "terminal"
        label: "Terminal"
        description: "Terminal binary used to host the SSH session; must support -e"
        placeholder: Quickshell.env("TERMINAL") || "ghostty"
        defaultValue: Quickshell.env("TERMINAL") || "ghostty"
    }

    StringSetting {
        settingKey: "ssh_command"
        label: "SSH Command"
        placeholder: "ssh"
        defaultValue: "ssh"
    }

    SelectionSetting {
        settingKey: "sort_mode"
        label: "Sort Recorded Hosts"
        description: "Order hosts by connection frequency or by most recent connection"
        options: [
            { label: "Most frequent", value: "frequency" },
            { label: "Most recent", value: "recency" }
        ]
        defaultValue: "frequency"
    }

    ToggleSetting {
        settingKey: "probe_enabled"
        label: "Verify Before Recording"
        description: "Run a quick BatchMode connection check before recording. Key-based logins record on success; password logins record because the server was reached. Typos and unreachable hosts are not recorded."
        defaultValue: true
    }

    SliderSetting {
        settingKey: "connect_timeout"
        label: "Connect Timeout"
        description: "Seconds allowed for the success check before opening the terminal"
        defaultValue: 2
        minimum: 1
        maximum: 10
        unit: "s"
    }

    SliderSetting {
        settingKey: "max_hosts"
        label: "Maximum Recorded Hosts"
        defaultValue: 100
        minimum: 10
        maximum: 500
    }

    ToggleSetting {
        settingKey: "scope_launch"
        label: "Launch in Systemd Scope"
        description: "Run the terminal through systemd-run so restarting DMS does not kill the SSH session"
        defaultValue: true
    }
}
