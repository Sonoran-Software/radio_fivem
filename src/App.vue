<template>
    <div class="appcontainer">
        <div v-if="dragMode" class="drag-instructions">
            <div>
                Click and drag to move the components. Press <code>ESC</code> to save.
            </div>
        </div>

        <draggable-box
            v-for="frame in activeFrames"
            :style="{fontSize: `${size}px`}"
            :key="frame.type"
            v-model="positions[frame.type]"
            :drag-enabled="dragMode"
        >
            <div class="radio-body">
                <skin-body-img v-if="frame.body" :body-skin="frame.body" />

                <skin-body-component v-if="frame.screen" :bounds="frame.screen">
                    <primary-screen :on="radioPower">
                        <component
                            v-if="radioPower && screenDynComponent"
                            :is="screenDynComponent"
                            :skin-options="selectSkinOptions()"
                            @set-screen="setScreen($event)"
                            @go-home="goToPreset(0)"
                            @set-frequency="setFrequency($event)"
                            @send-message="sendRadioMessage($event)"
                            @add-scanned="addScanned($event)"
                            @del-scanned="delScanned($event)"
                            @toggle-scan="toggleScan($event)"
                            @set-skin-id="selectSkin($event)"
                            @set-drag="dragMode = true"
                        />
                    </primary-screen>
                </skin-body-component>

                <skin-body-component v-if="frame.miniScreen" :bounds="frame.miniScreen">
                    <mini-screen v-if="radioPower" />
                </skin-body-component>

                <skin-body-component v-for="(ctrl, i) in frame.controls" :key="i" :bounds="ctrl">
                    <button class="radio-control" v-on="ctrl.events"></button>
                </skin-body-component>
            </div>
        </draggable-box>
    </div>
</template>

<script>
import SkinBodyImg from './components/skin/BodyImage.vue'
import SkinBodyComponent from './components/skin/BodyComp.vue';
import DraggableBox from './components/util/DraggableBox.vue'
import MiniScreen from './components/MiniScreen.vue'
import Screen from './components/Screen.vue'

import Home from './components/Home.vue'
import Channels from './components/Channels.vue'
import Channel from './components/Channel.vue'
import Message from './components/Message.vue'
import ScanList from './components/ScanList.vue'
import Settings from './components/Settings.vue'
import Contacts from './components/Contacts.vue'
import CallDetails from './components/CallDetails.vue'

export default {
    components: {
        SkinBodyImg,
        SkinBodyComponent,
        DraggableBox,
        MiniScreen,
        PrimaryScreen: Screen,

        Home,
        Channels,
        Channel,
        Message,
        ScanList,
        Settings,
        Contacts,
        CallDetails,
    },
    data: () => {
        return {
            showRadio: false,
            showTopRadio: false,
            showMobileRadio: false,
            radioPower: false,
            currPreset: 0,
            currScreen: "",
            topRadioSize: "lg",
            inVehicle: false,

            dragMode: false,
            positions: {
                portable: [0, 0],
                vehicle: [0, 0],
                hud: [400, 0]
            },
            size: 16,

            // promises of queried skin data (so we don't query twice)
            // Record<string, Promise<SkinData> | SkinData>
            skinCache: {},
            selectSkinIds: ['default', 'ems'], // list of skin ids that can be selected
            // curSkinId: 'default',
            curSkin: null,
        }
    },
    computed: {
        stateFreqName() {
            return this.$store.getters.freqName;
        },
        screenDynComponent() {
            const c = this.$options.components;
            const ROUTES = {
                '': c.Home,
                'calldetails': c.CallDetails,
                'channels': c.Channels,
                'channel': c.Channel,
                'contacts': c.Contacts,
                'message': c.Message,
                'scanlist': c.ScanList,
                'settings': c.Settings,
            };
            return ROUTES[this.currScreen];
        },
        activeFrames() {
            if (!this.curSkin) return; // no skin for the frames

            const getFrame = (type) => {
                const find = this.curSkin.frames.find(x => x.type === type)
                if (find) return find;
                const first = this.curSkin.frames[0];
                return { ...first, type };
            };

            const frames = [];
            if (this.showRadio) frames.push(getFrame('portable'));
            if (this.showMobileRadio) frames.push(getFrame('vehicle'));
            if (this.showTopRadio) frames.push(getFrame('hud'));

            const ACTIONS = {
                'power': this.buttonPower,
                'next_preset': this.buttonNext,
                'prev_preset': this.buttonPrev,
                'panic': this.buttonPanic,
                'home': () => this.setScreen(''),
                'hide': () => this.hideRadio(true),
            };
            return frames.map((frame) => ({
                ...frame,
                controls: frame.controls.map((ctrl) => ({
                    ...ctrl,
                    events: { click: ACTIONS[ctrl.action] },
                })),
            }));
        },
    },
    watch: {
        stateFreqName(newVal, oldVal) {
            if (!this.$store.state.connected) return;
            this.notifyPlayer("Channel: ~y~" + newVal || 'Custom Frequency');
        }
    },
    created() {
        this.setupSocket();
        window.addEventListener('keyup', (event) => {
            //console.log(event.code);
            switch (event.code) {
                case "Escape":
                    if (this.dragMode) {
                        this.dragMode = false;
                        // save the positions by sending them back to the client
                        this.postClient({
                            type: 'setUiPositions', data: this.positions
                        });
                    } else {
                        this.hideRadio(false);
                    }
                    break;

                // TODO: remove after development
                case 'ArrowUp':
                    this.size += 1;
                    break;
                case 'ArrowDown':
                    this.size -= 1;
                    break;
                // case 'ArrowUp':
                // case 'ArrowDown':
                // case 'ArrowLeft':
                // case 'ArrowRight':
                //     this.nudgeSkinProperty(event.code);
                //     break;
            
                default:
                    break;
            }
        })
    },
    mounted() {
        this.selectSkin('default');

        window.addEventListener('message', (event) => {
            switch (event.data.type) {
                case 'reset':
                    this.setupSocket();
                    break;
                case 'power':
                    this.radioPower = event.data.power || !this.radioPower;
                    this.$store.state.gamestate.radio_powered = this.radioPower;
                    this.postClient({
                        type: 'power',
                        power: this.radioPower 
                    });
                    this.updateGamestate();
                    break;
                case 'setVisible':
                    if (this.inVehicle && this.radioPower) {
                        this.showMobileRadio = event.data.visibility;
                        this.showRadio = false;
                    } else {
                        this.showMobileRadio = false;
                        this.showRadio = event.data.visibility;
                    }
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
                case 'radioHud':
                    switch (event.data.size) {
                        case 'off':
                            this.showTopRadio = false;
                            break;
                        case 'small':
                            this.showTopRadio = true;
                            this.topRadioSize = "sm";
                            break;
                        case 'medium':
                            this.showTopRadio = true;
                            this.topRadioSize = "md";
                            break;
                        case 'large':
                            this.showTopRadio = true;
                            this.topRadioSize = "lg";
                            break;
                        default:
                            console.error("Invalid Hud Size Specified.");
                            break;
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
                case 'goToPreset':
                    this.goToPreset(event.data.preset);
                    break;
                case 'callUpdate':
                    this.$store.commit('setCall', event.data.call);
                    break;
                case 'unitStatus':
                    this.$store.commit('setUnitStatus', event.data.status);
                    break;
                case 'getRadios': 
                    let activeRadios = event.data.radios.filter(radio => radio && radio.id && radio.name);
                    this.$store.commit('setActiveRadios', activeRadios);
                    break;
                case 'inVehicle':
                    this.inVehicle = event.data.vehState;
                    this.$store.commit('setInVehicle', this.inVehicle);
                    //console.log("inVehicle: " + this.inVehicle);
                    this.updateRadioType();
                    break;
                case 'time':
                    this.$store.commit('setInGameTime', event.data.time);
                    break;
                case 'setUiPositions':
                    if (typeof event.data.data !== 'object') break;
                    for (const k in event.data.data) {
                        if (event.data.data[k] instanceof Array)
                            this.$set(this.positions, k, event.data.data[k]);
                        else
                            console.warn('WARNING: skip in setUiPositions', k);
                    }
                    break;
                case 'setSkins':
                case 'setCurrentSkin':
                    if (event.data.skins) // update available skins
                        this.selectSkinIds = event.data.skins;
                    if (event.data.skin) // update current ski
                        this.selectSkin(event.data.skin);
                    break;
                case 'incomingMessage':
                    // this.notifyPlayer("Radio: ~b~New Message");
                    // let sendingradio = this.$store.state.radios.filter((obj) => {
                    //     return obj.id === event.data.sender;
                    // })
                    // this.$store.state.conversations.push({
                    //     senderid: sendingradio[0].id,
                    //     sender: sendingradio[0].name,
                    //     payload: event.data.payload
                    // })
                    // console.log(this.$store.state.conversations)
                    break;
                default:
                    break;
            }
        });
        // update the gamestate with an interval
        setInterval(this.updateGamestate.bind(this), 2500);
    },
    methods: {
        nudgeSkinProperty(key) {
            const NUDGE = 0.25;
            let wNudge = 0;
            let hNudge = 0;
            if (key === 'ArrowUp') hNudge = -NUDGE;
            else if (key === 'ArrowDown') hNudge = NUDGE;
            else if (key === 'ArrowLeft') wNudge = -NUDGE;
            else if (key === 'ArrowRight') wNudge = NUDGE;

            const prop = this.activeFrames[1].miniScreen;
            if (prop.top)
                this.$set(prop, 'top', prop.top + hNudge);
            if (prop.bottom)
                this.$set(prop, 'bottom', prop.bottom - hNudge);
            if (prop.left)
                this.$set(prop, 'left', prop.left + wNudge);
            if (prop.right)
                this.$set(prop, 'right', prop.right - wNudge);
            console.log(JSON.stringify(prop));
        },
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
        async querySkinNoCache(skinId) {
            const BASE = `https://cfx-nui-${GetParentResourceName()}/skins`;
            const res = await fetch(`${BASE}/${skinId}/skin.json`)
            const skinData = await  res.json()

            skinData.id = skinId;
            // add the base url to the image paths
            for (const frame of skinData.frames)
                if (frame.body?.image)
                    frame.body.image = `${BASE}/${skinId}/${frame.body.image}`;
            return skinData;
        },
        querySkin(skinId) {
            if (this.skinCache[skinId] instanceof Promise) return this.skinCache[skinId];
            else if (this.skinCache[skinId]) return Promise.resolve(this.skinCache[skinId]);

            const promise = this.querySkinNoCache(skinId);
            this.$set(this.skinCache, skinId, promise);
            promise.then(res => this.$set(this.skinCache, skinId, res));
            return promise;
        },
        extractSkin(skinId) {
            // this will take a skin from the cache if the promise is resolved, otherwise it will return undefined
            // in the event no cache entry exists, it will start a query
            const skin = this.skinCache[skinId];
            if (skin instanceof Promise) return undefined; // still loading
            else if (skin !== undefined) return skin; // fully queried

            this.querySkin(skinId);
            return undefined;
        },
        selectSkin(skinId) {
            this.querySkin(skinId).then(skin => this.curSkin = skin);
        },
        selectSkinOptions() {
            // NOTE: this cannot be a computed property because of this.extractSkin
            const skinOptions = [];
            for (const skinId of this.selectSkinIds) {
                const skin = this.extractSkin(skinId);
                if (skin === null) continue; // skin queried but invalid
                const name = skin?.name || "Loading...";

                skinOptions.push({
                    id: skinId,
                    name,
                });
            }
            return skinOptions;
        },
        updateRadioType() {
            if (this.showMobileRadio || this.showRadio) {
                if (this.inVehicle) {
                    this.showMobileRadio = true;
                    this.showRadio = false;
                } else {
                    this.showMobileRadio = false;
                    this.showRadio = true;
                }
            }
        },
        hideRadio(forceful) {
            this.postClient({ type: 'hide', force: forceful });
        },
        sendRadioMessage(event) {
            let recipient = event.recipient;
            let payload = event.payload;
            console.log(`msgOutbound: ${recipient} ${payload}`);
            this.postClient({ type: "msgOutbound", recipient: recipient, payload: payload});
            this.notifyPlayer("Radio: ~g~Message Sent");
        },
        notifyPlayer(message, ignorestate) {
            if (this.radioPower || ignorestate) this.postClient({ type: "notify", message: message});
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
        },
        setScreen(name) {
            this.currScreen = name || '';
        },
        nextPreset() {
            if (this.$store.state.presets[this.currPreset + 1]) {
                let nextPreset = this.$store.state.presets[this.currPreset + 1];
                this.$store.state.currFreq.recv = nextPreset.freq_recv;
                this.$store.state.currFreq.xmit = nextPreset.freq_xmit;
                this.setFrequency();
                this.currPreset++;
            }
        },
        prevPreset() {
            if (this.$store.state.presets[this.currPreset - 1]) {
                let nextPreset = this.$store.state.presets[this.currPreset - 1];
                this.$store.state.currFreq.recv = nextPreset.freq_recv;
                this.$store.state.currFreq.xmit = nextPreset.freq_xmit;
                this.setFrequency();
                this.currPreset--;
            }
        },
        goToPreset(number) {
            if (this.$store.state.presets[number]) {
                let nextPreset = this.$store.state.presets[number];
                this.$store.state.currFreq.recv = nextPreset.freq_recv;
                this.$store.state.currFreq.xmit = nextPreset.freq_xmit;
                this.setFrequency();
                this.currPreset = number;
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
                if (data.error) {
                    // Handle Error Status
                    if (data.msg) {
                        if (data.msg == "ws api endpoint blocked for subscription level") {
                            // Invalid Subscription Level
                            console.log("Sending to Socket Failed: Not available for sub level " + this.$store.state.sublvl);
                        }
                    }
                } else {
                    // for now, only accept events coming globally OR from the first connection
                    if (typeof data.cid !== 'undefined' && data.cid !== 1) return;

                    switch (data.type) {
                    case "recv_controller_data": {
                        const { state: currstate, config } = data.data;
                        this.$store.commit('setConnected', true);
                        this.$store.commit('setFreqs', {
                            recv: currstate.freq_recv,
                            xmit: currstate.freq_xmit
                        });
                        this.$store.commit('setScanList', currstate.freq_scan);
                        this.$store.commit('setScanState', currstate.enable_scan);
                        this.$store.commit('setConfig', config);
                        break;
                    }
                    case "frequencies_updated": {
                        const { freq_recv, freq_xmit } = data;
                        this.$store.commit('setFreqs', {
                            recv: freq_recv,
                            xmit: freq_xmit,
                        });
                        break;
                    }
                    case "frequencies_scanned_updated":
                        this.$store.commit('setScanList', data.freqs);
                        this.$store.commit('setScanState', data.enabled);
                        break;
                    case "channel_clients_changed":
                        // Ignore for Now, will be needed for messaging and status.

                        break;
                    case "controller_created": {
                        // Needs to set all of the controller config and status.
                        let {state, config} = data.data;
                        this.$store.commit('setConnected', true);
                        this.$store.commit('setFreqs', {
                            recv: state.freq_recv,
                            xmit: state.freq_xmit,
                        });
                        this.$store.commit('setScanList', state.freq_scan);
                        this.$store.commit('setScanState', state.enable_scan);
                        this.$store.commit('setConfig', config);
                        break;
                    }
                    case "controller_destroyed":
                        // Needs to zero out all of the controller config and status, and possibly display disconnected message.
                        this.$store.commit('setConnected', false);
                        break;
                    case "config_changed":
                        this.$store.commit('setConfig', data.data);
                        break;
                    case "client_xmit_change":
                        if (data.xmit_type.startsWith('self'))
                            this.postClient({
                                type: 'talking',
                                talking: data.xmit_type.includes('talk_permit')
                            });
                        this.$store.commit('addXmitState', data);
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
            this.setupSocket();
        },
        sendToSocket(data) {
            if (this.connection.readyState === WebSocket.OPEN)
                this.connection.send(JSON.stringify(data));
        },
        toggleScan(event) {
            this.$store.commit('setScanState', !this.$store.state.scanning);
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
            this.notifyPlayer("Radio: " + (this.radioPower?"~g~On~g~":"~r~Off~r~"), true);
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

.drag-instructions {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;

    display: flex;
    justify-content: center;
}
.drag-instructions > div {
    font-family: sans-serif;
    padding: 1rem;
    background-color: rgba(0,0,0,0.75);
    color: white;
}

.radio-body {
    position: relative;
}
.radio-control {
    outline: none;
    border: none;
    background-color: transparent;
    cursor: pointer;
}
</style>
