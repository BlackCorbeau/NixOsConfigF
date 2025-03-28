import { bind } from "astal"
import Wp from "gi://AstalWp"
import {execAsync} from "astal/process"

export default function Audio() {
    const speaker = Wp.get_default()?.audio.defaultSpeaker!

    return <box className="AudioSlider">
        <button onClicked={() => {execAsync("kitty --class pulsemixer -e pulsemixer")}}>
            <box spacing={4}> 
                <icon icon={bind(speaker, "volumeIcon")} />
                <label label={bind(speaker, "volume").as(v => `${Math.floor(v*100)}%`)} />
            </box>
        </button>
    </box>
}
