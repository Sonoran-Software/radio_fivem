<template>
    <div class="appcontainer" :class="{ debug, help }">
        <div v-if="dragMode" class="drag-instructions">
            <div>
                Click and drag to move the components.
                Hold <code>CTRL</code> to resize.
                Press <code>ESC</code> to save.
            </div>
        </div>

        <div v-if="debug && activeFrames">
            <div style="display:inline-block" class="label-on-top">
                <code>path = {{ nudgePath }}</code>
                <pre>{{ nudgeProp }}</pre>
            </div>
        </div>

        <draggable-box v-for="frame in activeFrames" :key="frame.type" :drag-enabled="dragMode"
            :value="positions[frame.key] || defaultPositions[frame.type]" @input="$set(positions, frame.key, $event)">
            <div class="radio-body">
                <skin-body-img v-if="frame.body" :body-skin="frame.body" />

                <skin-body-component v-if="frame.screen" :bounds="frame.screen"
                    @click="(nudgePath = [frame.type, 'screen'])">
                    <primary-screen :on="radioPower">
                        <floating-screen v-if="radioPower && standaloneServerId" :server-id="standaloneServerId"
                            :url="standaloneUrl" />
                        <component v-else-if="radioPower && screenDynComponent" :is="screenDynComponent"
                            :help-enabled="help" :skin-options="selectSkinOptions()" @set-screen="setScreen($event)"
                            @go-home="goToPreset(0)" @set-frequency="setFrequency($event)"
                            @send-message="sendRadioMessage($event)" @add-scanned="addScanned($event)"
                            @del-scanned="delScanned($event)" @toggle-scan="toggleScan($event)"
                            @set-skin-id="selectSkin($event)" @set-help="help = $event"
                            @enable-drag="dragMode = true" />
                    </primary-screen>
                </skin-body-component>

                <skin-body-component v-if="frame.miniScreen" :bounds="frame.miniScreen">
                    <mini-screen v-if="radioPower" />
                </skin-body-component>

                <skin-body-component v-for="(ctrl, i) in frame.controls" :key="i" :bounds="ctrl">
                    <button class="radio-control" v-on="ctrl.events"
                        @click.right="nudgePath = [frame.type, 'controls', i]"></button>
                    <code v-if="debug || help" class="label-on-top"
                        :class="{ 'hack': ctrl.action === 'next_preset' }">{{ ctrl.action }}</code>
                </skin-body-component>
            </div>
        </draggable-box>
    </div>
</template>

<script>
import SkinBodyImg from './components/skin/BodyImage.vue'
import SkinBodyComponent from './components/skin/BodyComp.vue'
import DraggableBox from './components/util/DraggableBox.vue'
import MiniScreen from './components/MiniScreen.vue'
import Screen from './components/Screen.vue'
import FloatingScreen, { frameEl } from './components/util/FloatingScreen.vue'

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
        FloatingScreen,

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
            debug: false,
            help: false,
            standaloneServerId: null,
            standaloneUrl: null,
            pttKeyName: null,

            showRadio: false,
            showTopRadio: false,
            showMobileRadio: false,
            radioPower: false,
            currPreset: 0,
            currScreen: "",
            topRadioSize: "lg",
            inVehicle: false,

            dragMode: false,
            defaultPositions: {
                portable: [0, 0, 16],
                vehicle: [0, 0, 16],
                hud: [400, 0, 16]
            },
            positions: {},

            // promises of queried skin data (so we don't query twice)
            // Record<string, Promise<SkinData> | SkinData>
            skinCache: {},
            selectSkinIds: [], // list of skin ids that can be selected
            curSkin: null,
            nudgePath: null,
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
                return first;
            };

            let frames = [];
            if (this.showRadio) frames.push(getFrame('portable'));
            if (this.showMobileRadio) frames.push(getFrame('vehicle'));
            if (this.showTopRadio) frames.push(getFrame('hud'));

            // dedupe frames by type
            frames = frames.filter((frame, i) => frames.findIndex((x) => x.type === frame.type) === i);

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
                    events: {
                        click: (e) => e.button === 0 && ACTIONS[ctrl.action](e)
                    }
                })),
            }));
        },
        nudgeProp() {
            if (!this.nudgePath) return null;

            const [frameType, ...path] = this.nudgePath;
            let prop = this.curSkin.frames.find(x => x.type === frameType);
            for (const key of path) prop = prop[key];

            return prop;
        }
    },
    watch: {
        stateFreqName(newVal, oldVal) {
            if (!this.$store.state.connected) return;
            this.notifyPlayer("Channel: ~y~" + newVal || 'Custom Frequency');
        }
    },
    created() {
        window.addEventListener('keyup', (event) => {
            this.onKeyPressed(event, 'keyup');
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
                case 'ArrowUp':
                case 'ArrowDown':
                case 'ArrowLeft':
                case 'ArrowRight':
                    this.debug && this.debugNudgeSkinProperty(event);
                    break;
                default:
                    break;
            }
        });
        window.addEventListener('keydown', (event) => {
            this.onKeyPressed(event, 'keydown');
        });
    },
    mounted() {
        this.selectSkin('default');
        window.addEventListener('message', (event) => {
            // if event is from frameEl (standalone screen), treat as socket message
            if (event.source === frameEl?.contentWindow)
                return void this.socketMessage(event.data);

            // accept a "debug" field with every message type to toggle ui dbg
            if (typeof event.data.debug === 'boolean')
                this.debug = event.data.debug;
            if (typeof event.data.standaloneId !== 'undefined')
                this.standaloneServerId = event.data.standaloneId;
            if (typeof event.data.standaloneUrl !== 'undefined')
                this.standaloneUrl = event.data.standaloneUrl;

            switch (event.data.type) {
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
                    this.pttKeyName = event.data.pttKey;
                    // this.showMobileRadio = event.data.visibility;
                    break;
                case 'ptt':
                    this.sendToSocket({ type: 'ptt', state: event.data.state });
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
                    this.showTopRadio = event.data.size !== 'off';
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
                    if (!event.data.radios) {
                        console.log('no radios!');
                        break;
                    }
                    // really event.data.radios is Record<number, object> but
                    // it could be provided as object[] if lua is dumb
                    let activeRadios = Object.values(event.data.radios).filter(radio => radio && radio.id && radio.name);
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
                    this.positions = event.data.data;
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
        onKeyPressed(e, type) {
            if (!this.pttKeyName) return;
            const matchesPtt = e.code === this.pttKeyName || (this.pttKeyName.startsWith('SpecialKey.') && e.code === this.pttKeyName.split('.')[1]);
            if (matchesPtt && !e.repeat) {
                e.preventDefault();
                this.sendToSocket({ type: 'ptt', state: type === 'keydown' });
            }
        },
        async querySkinNoCache(skinId) {
            const BASE = `https://cfx-nui-${GetParentResourceName()}/skins`;
            const res = await fetch(`${BASE}/${skinId}/skin.json`)
            const skinData = await res.json()

            skinData.id = skinId;
            for (const frame of skinData.frames) {
                // add the base url to the image paths
                if (frame.body?.image)
                    frame.body.image = `${BASE}/${skinId}/${frame.body.image}`;
                frame.key = `${skinId}-${frame.type}`;
            }
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
        debugNudgeSkinProperty({ code: direction, shiftKey }) {
            if (!this.nudgeProp) return;

            const NUDGE = 1 / 8;
            let wNudge = 0;
            let hNudge = 0;
            if (direction === 'ArrowUp') hNudge = -NUDGE;
            else if (direction === 'ArrowDown') hNudge = NUDGE;
            else if (direction === 'ArrowLeft') wNudge = -NUDGE;
            else if (direction === 'ArrowRight') wNudge = NUDGE;

            // even though this is a computed property, it pulls directly from
            // the data so it's fine to mutate it
            const prop = this.nudgeProp;
            if (shiftKey) {
                if (prop.height !== undefined)
                    this.$set(prop, 'height', prop.height - hNudge);
                else if (prop.bottom !== undefined)
                    this.$set(prop, 'bottom', prop.bottom + hNudge);
                else if (prop.top !== undefined)
                    this.$set(prop, 'top', prop.top - hNudge);

                if (prop.width !== undefined)
                    this.$set(prop, 'width', prop.width + wNudge);
                else if (prop.right !== undefined)
                    this.$set(prop, 'right', prop.right - wNudge);
                else if (prop.left !== undefined)
                    this.$set(prop, 'left', prop.left + wNudge);
            } else {
                if (prop.top !== undefined)
                    this.$set(prop, 'top', prop.top + hNudge);
                if (prop.bottom !== undefined)
                    this.$set(prop, 'bottom', prop.bottom - hNudge);
                if (prop.left !== undefined)
                    this.$set(prop, 'left', prop.left + wNudge);
                if (prop.right !== undefined)
                    this.$set(prop, 'right', prop.right - wNudge);
            }
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
            this.postClient({ type: "msgOutbound", recipient: recipient, payload: payload });
            this.notifyPlayer("Radio: ~g~Message Sent");
        },
        notifyPlayer(message, ignorestate) {
            if (this.radioPower || ignorestate) this.postClient({ type: "notify", message: message });
        },
        updateGamestate() {
            let message = {
                type: "set_gamestate",
                state: this.$store.state.gamestate
            }
            this.sendToSocket(message);
        },
        addScanned(event) {
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
                    console.log("Removed scanned freq: " + freq[0] + "." + freq[1]);
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
        setScreen(name) {
            this.currScreen = name || '';
        },
        nextPreset() {
            this.sendToSocket({
                type: 'preset_next',
            })
        },
        prevPreset() {
            this.sendToSocket({
                type: 'preset_prev',
            })
        },
        socketMessage(event) {
            switch (event.type) {
                case "radio_connected":
                    this.$store.commit('setConnected', true);
                    this.$store.commit('setSublvl', event.subscription);
                    break;
                case "radio_disconnected":
                    this.$store.commit('setConnected', false);
                    break;
            }
        },
        sendToSocket(data) {
            if (frameEl) frameEl.contentWindow.postMessage(data, '*');
            // else console.warn("frameEl does not exist, but tried to send message", data);
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
            if (!this.$store.state.connected)
                return void this.notifyPlayer("Radio: ~r~Not Connected")
            if (this.$store.state.sublvl == 0)
                return void this.notifyPlayer("Radio: ~r~Button Disabled (Free Mode)")
            this.notifyPlayer("Radio: ~y~Prev Preset");
            this.prevPreset();
        },
        buttonNext() {
            if (!this.$store.state.connected)
                return void this.notifyPlayer("Radio: ~r~Not Connected")
            if (this.$store.state.sublvl == 0)
                return void this.notifyPlayer("Radio: ~r~Button Disabled (Free Mode)")
            this.notifyPlayer("Radio: ~y~Next Preset");
            this.nextPreset();
        },
        buttonPower() {
            this.radioPower = !this.radioPower;
            if (this.standaloneServerId)
                this.$store.commit('setConnected', this.radioPower);

            this.$store.state.gamestate.radio_powered = this.radioPower;
            this.notifyPlayer("Radio: " + (this.radioPower ? "~g~On~g~" : "~r~Off~r~"), true);
            this.sendToSocket({ type: 'power', power: this.radioPower });
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

.drag-instructions>div {
    font-family: sans-serif;
    padding: 1rem;
    background-color: rgba(0, 0, 0, 0.75);
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

.label-on-top {
    font-size: 12px;
    /* the only instance where px values are ok */
    color: white;
    background: rgba(0, 0, 0, 0.5);
    z-index: 1000;
}

.label-on-top.hack {
    display: inline-block;
    transform: translateY(-16px);
    /* label-on-top uses pixel values */
}

.debug .radio-body {
    outline: 3px solid red;
}

.debug .radio-control,
.help .radio-control {
    outline: 2px solid green;
}
</style>
