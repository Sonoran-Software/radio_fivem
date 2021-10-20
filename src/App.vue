<template>
    <div class="appcontainer">
        <div v-if="showRadio">
            <div class="radio-container"
            :class="(showRadio?'radio-open':'radio-close')"
            >
                <div id="radio-body" class="radio-body"
                :style="{backgroundImage: 'url(../static/radio-frame.png)'}">
                    <div class="radio-controls">
                        <input type="button" class="ctrl ctrl-panic" v-on:click="buttonPanic();" />
                        <input type="button" class="ctrl ctrl-prev" v-on:click="buttonPrev();" />
                        <input type="button" class="ctrl ctrl-next" v-on:click="buttonNext();" />
                        <input type="button" class="ctrl ctrl-power" v-on:click="buttonPower();" />
                    </div>
                    <div class="radio-screen">
                        <div class="radio-brand">
                            <img class="radio-logo" :src="`../static/radio-logo.png`">
                        </div>
                        <div class="radio-content" v-if="radioPower">
                            <Home v-if="currScreen == ''" v-on:set-screen="setScreen($event)" />
                            <Channels v-if="currScreen == 'channels'" v-on:set-screen="setScreen($event)" v-on:set-frequency="setFrequency($event)" />
                            <Channel v-if="currScreen == 'channel'" v-on:set-screen="setScreen($event)" v-on:set-frequency="setFrequency($event)" />
                            <Contacts v-if="currScreen == 'contacts'" v-on:set-screen="setScreen($event)" />
                            <Message v-if="currScreen == 'message'" v-on:set-screen="setScreen($event)" />
                            <Messages v-if="currScreen == 'messages'" v-on:set-screen="setScreen($event)" />
                            <NewMessage v-if="currScreen == 'newmessage'" v-on:set-screen="setScreen($event)" />
                            <ScanList v-if="currScreen == 'scanlist'" v-on:set-screen="setScreen($event)" v-on:add-scanned="addScanned($event)" v-on:del-scanned="delScanned($event)" />
                            <Settings v-if="currScreen == 'settings'" v-on:set-screen="setScreen($event)" />
                        </div>
                    </div>
                    <div class="radio-buttons">
                        <input type="button" class="ctrl ctrl-home" @click="setScreen('');" />
                    </div>
                </div>
            </div>
        </div>
        <div v-if="showTopRadio">
            <div class="top-radio-container">
                <div id="top-radio-body" class="top-radio-body"
                    :style="{backgroundImage: 'url(../static/radio-frame-top.png)'}">

                </div>
            </div>
        </div>
    </div>
</template>

<script>
import Home from './components/Home.vue'
import Channels from './components/Channels.vue'
import Channel from './components/Channel.vue'
import Message from './components/Message.vue'
import NewMessage from './components/NewMessage.vue'
import ScanList from './components/ScanList.vue'
import Settings from './components/Settings.vue'
import Contacts from './components/Contacts.vue'
import Messages from './components/Messages.vue'

export default {
    components: {
        Home,
        Channels,
        Channel,
        Message,
        NewMessage,
        ScanList,
        Settings,
        Contacts,
        Messages
    },
    data: () => {
        return {
            showRadio: false,
            showTopRadio: false,
            radioPower: true,
            currPreset: 0,
            currScreen: ""
        }
    },
    created() {
        this.setupSocket();
        window.addEventListener('keyup', (event) => {
            //console.log(event.code);
            switch (event.code) {
                case "Escape":
                    this.postClient({ type: 'hide'});

                    break;
            
                default:
                    break;
            }
        })
    },
    mounted() {
        window.addEventListener('message', (event) => {
            const eventType = event.data.event;
            //console.log(event);
            switch (event.data.type) {
                case 'setVisible':
                    this.showRadio = event.data.visibility;
                    break;
                case 'setPos':
                    try {
                        let message = JSON.stringify({
                            type: "update_position",
                            to_cid: 1,
                            position: [
                                event.data.position[0],
                                event.data.position[1],
                                event.data.position[2]
                            ]
                        })
                        message = {
                            type: "update_position",
                            to_cid: 1,
                            position: [
                                event.data.position[0],
                                event.data.position[1],
                                event.data.position[2]
                            ]
                        }
                        // Causing Errors
                        this.sendToSocket(message);
                    } catch (e) {
                        console.error("Failed to update posistion");
                        console.error(e);
                    }
                    break;
                default:
                    break;
            }
        });
    },
    methods: {
        postClient(data, route = "/data") {
            const url = new URL(route, `https://sonoranradio`);
            fetch(url.toString(), {
                method: "POST",
                body: JSON.stringify(data),
            }).then((res) => {
                if (res.status !== 200)
                    return console.error(`failed request with code: ${res.status}`);

                const msg = res.json().then((data) => {
                    if (data !== "OK") console.error(`failed request with message: ${data}`);
                }).catch((err) => console.log(err));

            }).catch((err) => {
                console.log(err);
            });
        },
        addScanned(event) {
            console.log(event);
            this.$store.state.scanned.push(this.$store.state.currFreq.recv);
            this.sendToSocket({
                type: "set_frequencies_scanned",
                freqs: this.$store.state.scanned
            })
        },
        delScanned(event) {
            let freq = event.toString().split(",");
            console.log();
            let freqs = [];
            this.$store.state.scanned.forEach(el => {
                if (el[0] == freq[0] && el[1] == freq[1]) {
                    console.log("Removed scanned freq: "  +freq[0] + "." + freq[1]);
                } else {
                    freqs.push(el);
                }
            });
            this.$store.state.scanned = freqs;
            this.sendToSocket({
                type: "set_frequencies_scanned",
                freqs: freqs
            })
        },
        setFrequency(event) {
            //console.log("Setting Frequency: " + event);
            this.sendToSocket({
                type: "set_frequencies",
                freq_recv: this.$store.state.currFreq.recv,
                freq_xmit: this.$store.state.currFreq.xmit
            })
            this.$store.state.currFreq.name = "Custom Frequency";
            this.updateFreqLabel();
        },
        updateFreqLabel() {
            this.$store.state.presets.forEach(el => {
                //this.$store.state.currFreq.name = "Custom Frequency";
                try {
                    if (el.freq_recv[0] == this.$store.state.currFreq.recv[0] &&
                        el.freq_recv[1] == this.$store.state.currFreq.recv[1] &&
                        el.freq_xmit[0] == this.$store.state.currFreq.xmit[0] &&
                        el.freq_xmit[1] == this.$store.state.currFreq.xmit[1]) {
                            this.$store.state.currFreq.name = el.display_name;
                    }
                } catch (e) {
                    console.error(e);
                }
            })
        },
        setScreen(name) {
            //console.log(name);
            this.currScreen = name;
        },
        nextPreset() {

        },
        prevPreset() {

        },
        setupSocket() {
            //console.log("Establishing Websocket connection...");
            this.connection = new WebSocket("ws://[::1]:33802");
            this.connection.onmessage = this.socketMessage;
            this.connection.onopen = this.socketOpen;
            this.connection.onclose = this.socketClose;
        },
        socketMessage(event) {
            if (event.data) {
                let data = JSON.parse(event.data);
                //console.log("Received " + data.type + " message:");
                switch (data.type) {
                    case "recv_controller_data":
                        let currstate = data.data.state;
                        this.$store.state.statusText = "Connected";
                        this.$store.state.currFreq.name = "Custom Frequency";
                        this.$store.state.currFreq.recv = currstate.freq_recv;
                        this.$store.state.currFreq.xmit = currstate.freq_xmit;
                        this.$store.state.scanned = [];
                        currstate.freq_scan.forEach(el => {
                            this.$store.state.scanned.push([el[0], el[1]]);
                        })
                        let presetarr = data.data.config.profiles;
                        this.$store.state.presets = [];
                        presetarr.forEach(el => {
                            this.$store.state.presets.push({
                                display_name: el.display_name,
                                freq_recv: el.freq_recv,
                                freq_xmit: el.freq_xmit
                            })
                        });
                        break;
                    case "frequencies_updated":
                        this.$store.state.statusText = "Freq. Updated"; // TODO: Remove when status is configurable.
                        this.$store.state.currFreq.recv = data.freq_recv;
                        this.$store.state.currFreq.xmit = data.freq_xmit;
                        break;
                    case "frequencies_scanned_updated":
                        this.$store.state.scanned = [];
                        data.freqs.forEach(el => {
                            this.$store.state.scanned.push([el[0], el[1]]);
                        })
                        break;
                    case "channel_clients_changed":
                        // Ignore for Now, will be needed for messaging and status.

                        break;
                    case "controller_created":
                        // Needs to set all of the controller config and status.
                        let newstate = data.data.state;
                        this.$store.state.statusText = "Connected";
                        this.$store.state.currFreq.name = "Custom Frequency";
                        this.$store.state.currFreq.recv = newstate.freq_recv;
                        this.$store.state.currFreq.xmit = newstate.freq_xmit;
                        this.$store.state.scanned = [];
                        newstate.freq_scan.forEach(el => {
                            this.$store.state.scanned.push([el[0], el[1]]);
                        });
                        let newpresets = data.data.config.profiles;
                        this.$store.state.presets = [];
                        newpresets.forEach(el => {
                            this.$store.state.presets.push({
                                display_name: el.display_name,
                                freq_recv: el.freq_recv,
                                freq_xmit: el.freq_xmit
                            })
                        });
                        break;
                    case "controller_destroyed":
                        // Needs to zero out all of the controller config and status, and possibly display disconnected message.
                        this.$store.state.statusText = "Disconnected";
                        this.$store.state.currFreq.name = "Not Connected";
                        this.$store.state.currFreq.recv = ["xxx","xxx"];
                        this.$store.state.currFreq.xmit = ["xxx","xxx"];
                        break;
                    case "config_changed":
                        // Needs to update the current state with the new configuration.
                        let cfgpresets = data.profiles;
                        this.$store.state.presets = [];
                        cfgpresets.forEach(el => {
                            this.$store.state.presets.push({
                                display_name: el.display_name,
                                freq_recv: el.freq_recv,
                                freq_xmit: el.freq_xmit
                            })
                        });
                    default:
                        break;
                }
                this.updateFreqLabel();

                /**
                 * Received Events:
                 *  - RECV_CONTROLLERS          -IGNORE FOR NOW
                 *  - RECV_CONTROLLER_DATA      -DONE
                 *  - CHANNEL_CLIENTS_CHANGED   -IGNORE FOR NOW
                 *  - CONTROLLER_CREATED
                 *  - CONTROLLER_DESTROYED
                 *  - CONFIG_CHANGED
                 */
                //console.log(data);
            } else {
                console.error("Empty Message from Socket!");
            }
        },
        socketOpen(event) {
            console.log("Teamspeak Plugin Connected!");
            //this.sendToSocket({ "type" : "get_controllers" });
            this.sendToSocket({ "type" : "get_controller_data", "to_cid": 1 });
        },
        socketClose(event) {
            console.log(event);
            console.log("Socket connection lost, reconnecting...");
            this.setupSocket();
        },
        sendToSocket(data) {
            console.log("Sending Message to Socket");
            this.connection.send(JSON.stringify(data));
        },
        buttonPanic() {

        },
        buttonPrev() {

        },
        buttonNext() {

        },
        buttonPower() {
            this.radioPower = !this.radioPower
        }
    }
};
</script>

<style scoped>
.appcontainer {
    overflow: hidden;
}

.hidden {
    display: none;
}

.radio-open {
    -webkit-animation: radio-open 1s;
    top: 0;
    right: 0;
    bottom: 0;
    left: 0;
    overflow: hidden;
}
@keyframes radio-open {
    0% {
        position: absolute;
        transform: translate3d(0, 100vh, 0);
    }
    100% {
        position: absolute;
        transform: translate3d(0, 0, 0);
    }
}

.radio-close {
    -webkit-animation: radio-close 1s;
    top: 0;
    right: 0;
    bottom: 0;
    left: 0;
}
@keyframes radio-close {
    0% {
        position: absolute;
        transform: translate3d(0, 0, 0);
    }
    100% {
        position: absolute;
        transform: translate3d(0, 100vh, 0);
    }
}

.top-radio-body {
    background-repeat: round;
    width: 250px;
    height: 893px;
    position: fixed;
    right: 30px;
    /* right: 0px; */
    bottom: 0px;
    /* width: 200px;
    height: auto; */
    width: 275px;
    height: 982px;
}

.radio-body {
    background-repeat: round;
    width: 250px;
    height: 893px;
    position: fixed;
    right: 30px;
    /* right: 0px; */
    bottom: 0px;
    /* width: 200px;
    height: auto; */
    width: 275px;
    height: 982px;
}

.radio-controls {
    /* background-color: rgba(255,0,0,0.5); */
    margin-top: 482px;
    height: 67px;
    border-width: 0px;
    display: flex;
}

.radio-controls .ctrl:focus {
    outline: none;
}

.radio-controls .ctrl {
    position: relative;
    visibility: visible;
    opacity: 0.0;
    /* for development only */
    /* opacity: 0.3; */
}

.radio-controls .ctrl-panic {
    margin-left: 74px;
    border-radius: 35px;
    width: 30px;
    height: 18px; /* Originally 10px */
    margin-top: 48px; /* Originally 50px */ 
}


.radio-controls .ctrl-prev {
    height: 65px;
    margin-left: 10px;
    width: 22px;
}

.radio-controls .ctrl-next {
    height: 65px; /* Originally 10px */
    margin-left: 0px;
    width: 22px;
}

.radio-controls .ctrl-power {
    height: 45px; /* Originally 10px */
    margin-left: 44px;
    width: 50px;
    margin-top: 28px;
    border-radius: 20px;
}

.radio-screen {
    background-color:black;
    margin: 66px 63px 16px 63px;
    height: 270px;
}

.radio-brand {
    margin: 1px 1px 0px 1px;
    display: flex;
    flex-direction: column;
    align-items: center;
    height: 20px;
    justify-content: center;
    background: linear-gradient(to bottom, rgba(80,80,80,0.5) 0%, rgba(20,20,20,1) 100%);

}

.radio-logo {
    height: 12px;
    padding-top: 1px;
    /* transform: skewX(-20deg); */
}

.radio-content {
    border: 0px;
    height: 250px;
    margin: 0px 1px 1px 1px;
    width: 147px;
    overflow-y: scroll;
    overflow-x: hidden;
}

.radio-content::-webkit-scrollbar {
    display: none;
}

.radio-buttons {
    /* background-color: rgba(0,0,255,0.5); */
    height: 25px;
    margin: 0px 110px;
    display: flex;
}

.radio-buttons .ctrl {
    position: relative;
    visibility: visible;
    opacity: 0.0;
    /* for development only */
    /* opacity: 0.3; */
}

.radio-buttons .ctrl-home {
    width: 100%;
    border-radius: 20px;
}

</style>