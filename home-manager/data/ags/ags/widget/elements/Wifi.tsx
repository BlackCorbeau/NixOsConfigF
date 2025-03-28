import { bind } from "astal"
import Network from "gi://AstalNetwork"
import {execAsync} from "astal/process"

/*export default function Wifi() {
    const network = Network.get_default()
    const wifi = bind(network, "wifi")

    return <box visible={wifi.as(Boolean)}>
        {wifi.as(wifi => wifi && (
            <icon
                tooltipText={bind(wifi, "ssid").as(String)}
                className="Wifi"
                icon={bind(wifi, "iconName")}
            />
        ))}
    </box>
}*/

export default function Wifi() {
    const network = Network.get_default()
    const wifi = bind(network, "wifi")

    return <box visible={wifi.as(Boolean)}>
        {wifi.as(wifi => wifi && (
            <button onClicked={() => {execAsync("kitty --title=nmtui -e nmtui")}} className="Wifi">
                <box spacing={4}>
                    <icon icon={bind(wifi, "iconName")}/>
                    <label label={wifi.ssid.slice(0, 10) + (wifi.ssid.length > 10 ? "…" : "")}/>
                </box>
            </button>
        ))}
    </box>
}
