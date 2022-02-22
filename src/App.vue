<template>
    <div class="appcontainer">
        <div v-if="showRadio">
            <div class="radio-container"
            :class="(showRadio?'radio-open':'radio-close')"
            >
                <div id="radio-body" class="radio-body"
                :style="{backgroundImage: 'url(../static/radio-portable.png)'}">
                    <div class="radio-controls">
                        <input type="button" class="ctrl ctrl-panic" v-on:click="buttonPanic();" />
                        <input type="button" class="ctrl ctrl-prev" v-on:click="buttonPrev();" />
                        <input type="button" class="ctrl ctrl-next" v-on:click="buttonNext();" />
                        <input type="button" class="ctrl ctrl-power" v-on:click="buttonPower();" />
                    </div>
                    <div class="radio-screen">
                        <div class="radio-content" v-if="radioPower">
                            <Home v-if="currScreen == ''" v-on:set-screen="setScreen($event)" v-on:go-home="goToPreset(0)" />
                            <CallDetails v-if="currScreen == 'calldetails'" v-on:set-screen="setScreen($event)" />
                            <Channels v-if="currScreen == 'channels'" v-on:set-screen="setScreen($event)" v-on:set-frequency="setFrequency($event)" />
                            <Channel v-if="currScreen == 'channel'" v-on:set-screen="setScreen($event)" v-on:set-frequency="setFrequency($event)" />
                            <Contacts v-if="currScreen == 'contacts'" v-on:set-screen="setScreen($event)" />
                            <Message v-if="currScreen == 'message'" v-on:set-screen="setScreen($event)" v-on:send-message="sendRadioMessage($event)"/>
                            <Messages v-if="currScreen == 'messages'" v-on:set-screen="setScreen($event)" />
                            <NewMessage v-if="currScreen == 'newmessage'" v-on:set-screen="setScreen($event)" />
                            <ScanList v-if="currScreen == 'scanlist'" v-on:set-screen="setScreen($event)" v-on:add-scanned="addScanned($event)" v-on:del-scanned="delScanned($event)" v-on:toggle-scan="toggleScan($event)" />
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
                    :style="{backgroundImage: 'url(../static/radio-portable-top.png)'}">
                    <input type="button" v-on:click="sendRadioMessage(1, { message: 'hello' });" />
                </div>
            </div>
        </div>
        <div v-if="showMobileRadio">
            <div class="mobile-radio-container">
                <div id="mobile-radio-body" class="mobile-radio-body"
                    :style="{backgroundImage: 'url(../static/radio-mobile.png)'}">
                    <div class="mobile-radio-buttons">
                        <input type="button" class="mobile-ctrl mobile-ctrl-home" @click="setScreen('');" />
                    </div>
                    <div class="mobile-radio-screen">
                        <div class="mobile-radio-content" v-if="radioPower">
                            <Home v-if="currScreen == ''" v-on:set-screen="setScreen($event)" v-on:go-home="goToPreset(0)" />
                            <CallDetails v-if="currScreen == 'calldetails'" v-on:set-screen="setScreen($event)" />
                            <Channels v-if="currScreen == 'channels'" v-on:set-screen="setScreen($event)" v-on:set-frequency="setFrequency($event)" />
                            <Channel v-if="currScreen == 'channel'" v-on:set-screen="setScreen($event)" v-on:set-frequency="setFrequency($event)" />
                            <Contacts v-if="currScreen == 'contacts'" v-on:set-screen="setScreen($event)" />
                            <Message v-if="currScreen == 'message'" v-on:set-screen="setScreen($event)" />
                            <Messages v-if="currScreen == 'messages'" v-on:set-screen="setScreen($event)" />
                            <NewMessage v-if="currScreen == 'newmessage'" v-on:set-screen="setScreen($event)" />
                            <ScanList v-if="currScreen == 'scanlist'" v-on:set-screen="setScreen($event)" v-on:add-scanned="addScanned($event)" v-on:del-scanned="delScanned($event)" v-on:toggle-scan="toggleScan($event)" />
                            <Settings v-if="currScreen == 'settings'" v-on:set-screen="setScreen($event)" />
                        </div>
                    </div>
                    <div class="mobile-radio-controls">
                        <input type="button" class="mobile-ctrl mobile-ctrl-panic" v-on:click="buttonPanic();" />
                        <input type="button" class="mobile-ctrl mobile-ctrl-prev" v-on:click="buttonPrev();" />
                        <input type="button" class="mobile-ctrl mobile-ctrl-next" v-on:click="buttonNext();" />
                        <input type="button" class="mobile-ctrl mobile-ctrl-power" v-on:click="buttonPower();" />
                    </div>
                    <div class="mobile-radio-end">
                        <input type="button" class="mobile-ctrl mobile-ctrl-panic" v-on:click="buttonPanic();" />
                        <input type="button" class="mobile-ctrl mobile-ctrl-power" v-on:click="buttonPower();" />
                    </div>
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
import CallDetails from './components/CallDetails.vue'

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
        Messages,
        CallDetails
    },
    data: () => {
        return {
            showRadio: false,
            showTopRadio: false,
            showMobileRadio: false,
            radioPower: false,
            subLevel: null,
            currPreset: 0,
            currScreen: "",
            inVehicle: false
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
                case 'reset':
                    this.setupSocket();
                    break;
                case 'setVisible':
                    this.showRadio = event.data.visibility;
                    // this.showMobileRadio = event.data.visibility;
                    break;
                case 'setTowerQuality':
                    try {
                        this.$store.state.gamestate.tower_quality = event.data.state.tower_quality
                    } catch (e) {
                        console.error("Failed to update tower quality");
                        console.error(e);
                    }
                    break;
                case 'setPos':
                    try {
                        this.$store.state.gamestate.position = [
                            event.data.position[0],
                            event.data.position[1],
                            event.data.position[2]
                        ];
                    } catch (e) {
                        console.error("Failed to update posistion");
                        console.error(e);
                    }
                    break;
                case 'pushButton':
                    switch (event.data.button) {
                        case 'prev':
                            this.buttonPrev();
                            break;

                        case 'next':
                            this.buttonNext();
                            break;

                        case 'power':
                            this.buttonPower();
                            break;

                        case 'panic':
                            this.buttonPanic();
                            break;
                    
                        default:
                            break;
                    }
                    break;
                case 'callUpdate':
                    try {
                        console.log(event.data.call);
                        let call = event.data.call;
                        this.$store.state.call.code = call.code;
                        this.$store.state.call.title = call.title;
                        this.$store.state.call.location = (call.postal != ""?call.postal + " " + call.address : call.address);
                        this.$store.state.call.description = call.description;
                        this.$store.state.connColor = "green";
                    } catch (e) {
                        console.error("Failed to update call information");
                        console.error(e);
                    }
                    break;
                case 'unitStatus':
                    let status = "Unknown";
                    switch (event.data.status) {
                        case 0:
                            this.$store.state.statusText = "Unavailable";
                            break;
                        case 1:
                            this.$store.state.statusText = "Busy";
                            break;
                        case 2:
                            this.$store.state.statusText = "Available";
                            break;
                        case 3:
                            this.$store.state.statusText = "En Route";
                            break;
                        case 4:
                            this.$store.state.statusText = "On Scene";
                            break;
                        default:
                            this.$store.state.statusText = "Clocked Out";
                            break;
                    }
                    if (event.data.status > 0) this.$store.state.connColor = "green";

                    break;
                case 'getRadios':
                    let activeRadios = [];
                    event.data.radios.forEach(radio => {
                        if (radio) {
                            //console.log(`Radio ID: ${radio.id} Radio Name: ${radio.name}`)
                            if (radio.id && radio.name) activeRadios.push(radio);
                        }
                    });
                    this.$store.state.radios = activeRadios;
                    break;
                case 'inVehicle':
                    this.inVehicle = event.data.vehState;
                    console.log("inVehicle: " + this.inVehicle);
                    this.updateRadioType();
                    break;
                case 'incomingMessage':
                    this.notifyPlayer("Radio: ~b~New Message");
                    let sendingradio = this.$store.state.radios.filter((obj) => {
                        return obj.id === event.data.sender;
                    })
                    this.$store.state.conversations.push({
                        senderid: sendingradio[0].id,
                        sender: sendingradio[0].name,
                        payload: event.data.payload
                    })
                    console.log(this.$store.state.conversations)
                    break;
                default:
                    break;
            }
        });
        // update the gamestate with an interval
        setInterval(this.updateGamestate.bind(this), 2500);
    },
    // beforeUnmount() {
    //     window.removeEventListener('message');
    // },
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
        updateRadioType() {
            // if (this.showMobileRadio || this.showRadio) {
            //     if (this.inVehicle) {
            //         this.showMobileRadio = true;
            //         this.showRadio = false;
            //     } else {
            //         this.showMobileRadio = false;
            //         this.showRadio = true;
            //     }
            // }
        },
        sendRadioMessage(event) {
            let recipient = event.recipient;
            let payload = event.payload;
            console.log(`msgOutbound: ${recipient} ${payload}`)
            this.postClient({ type: "msgOutbound", recipient: recipient, payload: payload});
            this.notifyPlayer("Radio: ~g~Message Sent");
        },
        notifyPlayer(message) {
            if (this.radioPower) this.postClient({ type: "notify", message: message});
        },
        updateGamestate() {
            let message = {
                type: "set_gamestate",
                to_cid: 1,
                state: this.$store.state.gamestate
            }
            this.sendToSocket(message);
        },
        addScanned(event) {
            //console.log(event);
            this.$store.state.scanned.push(this.$store.state.currFreq.recv);
            this.sendToSocket({
                type: "set_frequencies_scanned",
                freqs: this.$store.state.scanned
            })
        },
        delScanned(event) {
            let freq = event.toString().split(",");
            //console.log();
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
            console.log("Setting Frequency: " + this.$store.state.currFreq.recv.toString() + this.$store.state.currFreq.xmit.toString() );
            this.sendToSocket({
                type: "set_frequencies",
                freq_recv: [parseInt(this.$store.state.currFreq.recv[0]),parseInt(this.$store.state.currFreq.recv[1])],
                freq_xmit: [parseInt(this.$store.state.currFreq.xmit[0]),parseInt(this.$store.state.currFreq.xmit[1])]
            })
            this.$store.state.currFreq.name = "Custom Frequency";
            this.updateFreqLabel();
        },
        updateFreqLabel() {
            let custom = true;
            this.$store.state.presets.forEach(el => {
                //this.$store.state.currFreq.name = "Custom Frequency";
                try {
                    if (el.freq_recv[0] == this.$store.state.currFreq.recv[0] &&
                        el.freq_recv[1] == this.$store.state.currFreq.recv[1] &&
                        el.freq_xmit[0] == this.$store.state.currFreq.xmit[0] &&
                        el.freq_xmit[1] == this.$store.state.currFreq.xmit[1]) {
                            this.$store.state.currFreq.name = el.display_name;
                            this.notifyPlayer("Channel: ~y~" + el.display_name);
                            custom = false;
                    }
                } catch (e) {
                    console.error(e);
                }
            });
            if (custom) {
                this.$store.state.currFreq.name = "Custom Frequency";
                this.notifyPlayer("Channel: ~y~Custom Frequency");
            }
        },
        setScreen(name) {
            //console.log(name);
            this.currScreen = name;
        },
        nextPreset() {
            if (this.$store.state.presets[this.currPreset + 1]) {
                let nextPreset = this.$store.state.presets[this.currPreset + 1];
                this.$store.state.currFreq.recv = nextPreset.freq_recv;
                this.$store.state.currFreq.xmit = nextPreset.freq_xmit;
                this.setFrequency();
                this.currPreset++;
                this.updateFreqLabel();
            }
        },
        prevPreset() {
            if (this.$store.state.presets[this.currPreset - 1]) {
                let nextPreset = this.$store.state.presets[this.currPreset - 1];
                this.$store.state.currFreq.recv = nextPreset.freq_recv;
                this.$store.state.currFreq.xmit = nextPreset.freq_xmit;
                this.setFrequency();
                this.currPreset--;
                this.updateFreqLabel();
            }
        },
        goToPreset(number) {
            if (this.$store.state.presets[number]) {
                let nextPreset = this.$store.state.presets[number];
                this.$store.state.currFreq.recv = nextPreset.freq_recv;
                this.$store.state.currFreq.xmit = nextPreset.freq_xmit;
                this.setFrequency();
                this.currPreset = number;
                this.updateFreqLabel();
            }
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
                //console.log(data);
                if (data.error) {
                    // Handle Error Status
                    if (data.msg) {
                        if (data.msg == "ws api endpoint blocked for subscription level") {
                            // Invalid Subscription Level
                            console.log("Sending to Socket Failed: Not available for sub level " + this.$store.state.sublvl);
                        }
                    }
                } else {
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
                        this.$store.state.scanning = currstate.enable_scan;
                        let presetarr = data.data.config.profiles;
                        this.$store.state.presets = [];
                        presetarr.forEach(el => {
                            this.$store.state.presets.push({
                                display_name: el.display_name,
                                freq_recv: el.freq_recv,
                                freq_xmit: el.freq_xmit
                            })
                        });
                        this.$store.state.sublvl = data.data.config.sublvl;
                        this.$store.state.connColor = "lightblue";
                        this.$store.state.connColorDefault = "lightblue";
                        this.updateFreqLabel();
                        break;
                    case "frequencies_updated":
                        this.$store.state.currFreq.recv = data.freq_recv;
                        this.$store.state.currFreq.xmit = data.freq_xmit;
                        this.updateFreqLabel();
                        break;
                    case "frequencies_scanned_updated":
                        this.$store.state.scanned = [];
                        data.freqs.forEach(el => {
                            this.$store.state.scanned.push([el[0], el[1]]);
                        })
                        this.$store.state.scanning = data.enabled;
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
                        this.$store.state.connColor = "lightblue";
                        this.$store.state.connColorDefault = "lightblue";
                        break;
                    case "controller_destroyed":
                        // Needs to zero out all of the controller config and status, and possibly display disconnected message.
                        this.$store.state.statusText = "Disconnected";
                        this.$store.state.currFreq.name = "Not Connected";
                        this.$store.state.currFreq.recv = ["xxx","xxx"];
                        this.$store.state.currFreq.xmit = ["xxx","xxx"];
                        this.$store.state.connColor = "gray";
                        this.$store.state.connColorDefault = "gray";
                        break;
                    case "config_changed":
                        // Needs to update the current state with the new configuration.
                        let cfgpresets = data.data.profiles;
                        this.$store.state.presets = [];
                        cfgpresets.forEach(el => {
                            this.$store.state.presets.push({
                                display_name: el.display_name,
                                freq_recv: el.freq_recv,
                                freq_xmit: el.freq_xmit
                            })
                        });
                        break;
                    case "client_xmit_change":
                        if (data.can_hear) {
                            switch (data.xmit_type) {
                                case "self_talk_permit":
                                    this.$store.state.voicestate.xmit = true;
                                    this.$store.state.voicestate.recv = false;
                                    this.$store.state.voicestate.talker = data.client.nickname;
                                    this.$store.state.connColor = "red";
                                    this.postClient({ type: 'talking', talking: true })
                                    break;
                                case "self_squelch":
                                    this.$store.state.voicestate.xmit = false;
                                    this.$store.state.voicestate.recv = false;
                                    this.$store.state.voicestate.talker = "";
                                    this.$store.state.connColor = this.$store.state.connColorDefault;
                                    this.postClient({ type: 'talking', talking: false })
                                    break;
                                case "unit_talk_permit":
                                    this.$store.state.voicestate.xmit = false;
                                    this.$store.state.voicestate.recv = true;
                                    this.$store.state.voicestate.talker = data.client.nickname;
                                    this.$store.state.connColor = "yellow";
                                    break;
                                case "unit_squelch":
                                    this.$store.state.voicestate.xmit = false;
                                    this.$store.state.voicestate.recv = false;
                                    this.$store.state.voicestate.talker = "";
                                    this.$store.state.connColor = this.$store.state.connColorDefault;
                                    break;
                                default:
                                    break;
                            }
                            if (data.xmit_type == "self_talk_permit") {
                                console.log("Self Talk Permit")

                            } else if (data.xmit_type == "self_squelch") {
                                console.log("Self Squelch")
                            }
                        }
                        break;
                    default:
                        console.log("**Unhandled Socket Message**");
                        console.log(JSON.stringify(event.data))
                        break;
                }

                }

            } else {
                console.error("Empty Message from Socket!");
            }
        },
        socketOpen(event) {
            console.log("Connected to teamspeak plugin...");
            this.sendToSocket({ "type" : "get_controller_data", "to_cid": 1 });
        },
        socketClose(event) {
            //console.log("Socket connection lost, reconnecting...");
            this.setupSocket();
        },
        sendToSocket(data) {
            try {
                // Suppress Any Connection Issues
                // TODO: Replace with checking the connection state.
                this.connection.send(JSON.stringify(data));
            } catch (err) {

            }
        },
        toggleScan(event) {
            //console.log(event);
            this.$store.state.scanning = !this.$store.state.scanning;
            this.sendToSocket({
                type: "set_scanning_enabled",
                enabled: this.$store.state.scanning
            })
        },
        buttonPanic() {
            this.notifyPlayer("Radio: ~r~Panic Pressed!");
            this.postClient({
                type: "panic"
            });
        },
        buttonPrev() {
            if (this.$store.state.sublvl == 0) {
                this.notifyPlayer("Radio: ~r~Button Disabled (Free Mode)")
            } else {
                this.notifyPlayer("Radio: ~y~Prev Preset");
                this.prevPreset();
            }
        },
        buttonNext() {
            if (this.$store.state.sublvl == 0) {
                this.notifyPlayer("Radio: ~r~Button Disabled (Free Mode)")
            } else {
                this.notifyPlayer("Radio: ~y~Next Preset");
                this.nextPreset();
            }
        },
        buttonPower() {
            this.radioPower = !this.radioPower;
            this.$store.state.gamestate.radio_powered = this.radioPower;
            this.notifyPlayer("Radio: " + (this.radioPower?"~g~On~g~":"~r~Off~r~"));
            this.postClient({
                type: 'power',
                power: this.radioPower 
            });
            this.updateGamestate();
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

.mobile-radio-body {
    background-repeat: round;
    width: 722px;
    height: 240px;
    position: fixed;
    right: 30px;
    bottom: 0px;
    height: 250px;
    display: flex;
    flex-direction: row;
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
    height: 1040px;
    position: fixed;
    right: 30px;
    /* right: 0px; */
    bottom: 0px;
    /* width: 200px;
    height: auto; */
    width: 275px;
    height: 982px;
}

.mobile-radio-controls {
    background-color: rgba(255, 0, 0, 0.5);
    margin-top: 482px;
    height: 67px;
    border-width: 0px;
    display: flex;
}

.mobile-radio-controls .mobile-ctrl:focus {
    outline: none;
}

.mobile-radio-controls .mobile-ctrl {
    position: relative;
    visibility: visible;
    opacity: 0.3;
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

.mobile-radio-controls .ctrl:focus {
    outline: none;
}

.mobile-radio-controls .ctrl {
    position: relative;
    visibility: visible;
    opacity: 0.0;
    /* for development only */
    opacity: 0.3;
}

.mobile-radio-controls .mobile-ctrl-panic {
    margin-left: 74px;
    border-radius: 35px;
    width: 30px;
    height: 18px; /* Originally 10px */
    margin-top: 48px; /* Originally 50px */ 
}


.mobile-radio-controls .mobile-ctrl-prev {
    height: 65px;
    margin-left: 10px;
    width: 22px;
}

.mobile-radio-controls .mobile-ctrl-next {
    height: 65px; /* Originally 10px */
    margin-left: 0px;
    width: 22px;
}

.mobile-radio-controls .mobile-ctrl-power {
    height: 45px; /* Originally 10px */
    margin-left: 44px;
    width: 50px;
    margin-top: 28px;
    border-radius: 20px;
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
    margin: 86px 51px 16px 52px;
    height: 264px;
}

.mobile-radio-screen {
    background-color:black;
    margin: 43px 15px 18px 0px;
    height: 167px;
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

.mobile-radio-content {
    border: 0px;
    height: 167px;
    margin: 0px 1px 1px 1px;
    width: 216px;
    overflow-y: scroll;
    overflow-x: hidden;
}

.mobile-radio-content::-webkit-scrollbar {
    display: none;
}

.radio-content {
    border: 0px;
    height: 264px;
    margin: 0px 1px 1px 1px;
    width: 169px;
    overflow-y: scroll;
    overflow-x: hidden;
}

.radio-content::-webkit-scrollbar {
    display: none;
}

.mobile-radio-buttons {
    background-color: rgba(0,0,255,0.5);
    width: 0px;
    margin: 35px 76px 169px 100px;
    height: 25px;
    display: flex;
}

.mobile-radio-buttons .mobile-ctrl {
    position: relative;
    visibility: visible;
    opacity: 0.0;
    /* for development only */
    opacity: 0.3;
}

.mobile-radio-buttons .mobile-ctrl-home {
    width: 30px;
    height: 30px;
    border-radius: 20px;
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
