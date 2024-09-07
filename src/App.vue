<template>
    <div class="appcontainer" :class="{ debug, help }">
        <div class="top-instructions">
            <div v-if="chatterNeedsInputHelp">
                Sonoran Radio needs input to continue. Press any key
            </div>
            <div v-else-if="dragMode">
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


        <!-- acts as standalone radio for hearing radios around the player -->
        <standalone-frame
            v-if="chatterEnabled"
            ref="standaloneFrame"
            :server-id="standaloneServerId"
            :url="standaloneUrl"
            chatter
        />

        <draggable-box v-for="frame in activeFrames" :key="frame.type" :drag-enabled="dragMode"
            :value="positions[frame.key] || defaultPositions[frame.type]" @input="$set(positions, frame.key, $event)">
            <div class="radio-body">
                <skin-body-img v-if="frame.body" :body-skin="frame.body" />

                <skin-body-component v-if="frame.screen" :bounds="frame.screen"
                    @click="(nudgePath = [frame.type, 'screen'])">
                    <primary-screen :on="radioPower">
                        <standalone-frame
                            v-if="radioPower && standaloneServerId && !dragMode"
                            ref="standaloneFrame"
                            :server-id="standaloneServerId"
                            :url="standaloneUrl"
                            @load="onStandaloneLoad"
                        />
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
import StandaloneFrame, { frameEl } from './components/StandaloneFrame.vue'

export default {
    components: {
        SkinBodyImg,
        SkinBodyComponent,
        DraggableBox,
        MiniScreen,
        PrimaryScreen: Screen,
        StandaloneFrame,
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

            chatterFeatureEnabled: false,
            chatterNeedsInput: false,
            chatterNeedsInputHelp: false,

            // promises of queried skin data (so we don't query twice)
            // Record<string, Promise<SkinData> | SkinData>
            skinCache: {},
            selectSkinIds: [], // list of skin ids that can be selected
            curSkin: null,
            nudgePath: null,
        }
    },
    computed: {
        showMobileRadio() {
            return this.showRadio && this.inVehicle;
        },
        stateFreqName() {
            return this.$store.getters.freqName;
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
            if (this.showMobileRadio) frames.push(getFrame('vehicle'));
            else if (this.showRadio) frames.push(getFrame('portable'));
            if (this.showTopRadio) frames.push(getFrame('hud'));

            // dedupe frames by type
            frames = frames.filter((frame, i) => frames.findIndex((x) => x.type === frame.type) === i);

            const ACTIONS = {
                'power': this.buttonPower,
                'next_preset': this.buttonNext,
                'prev_preset': this.buttonPrev,
                'panic': this.buttonPanic,
                'home': this.buttonHome,
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
        },
        skinNames() {
            const skinNames = {};
            for (const key in this.skinCache)
                if ('name' in this.skinCache[key])
                    skinNames[key] = this.skinCache[key].name;
            return skinNames;
        },
        chatterEnabled() {
            return this.chatterFeatureEnabled && !!this.standaloneServerId && !this.radioPower;
        }
    },
    watch: {
        stateFreqName(newVal) {
            if (!this.$store.state.connected) return;
            this.notifyPlayer("Channel: ~y~" + newVal || 'Custom Frequency');
        },
        skinNames() {
            this.updateAvailableSkins();
        }
    },
    created() {
        window.addEventListener('keyup', (event) => {
            this.onKeyPressed(event, 'keyup');
        });
        window.addEventListener('keydown', (event) => {
            this.onKeyPressed(event, 'keydown');
        });
    },
    mounted() {
        this.selectSkin('default');
        window.addEventListener('message', (event) => {
            if (event.data.type === 'keyup' || event.data.type === 'keydown')
                return void this.onKeyPressed(event.data, event.data.type);
            // if event is from frameEl (standalone screen), treat as socket message
            if (event.source === frameEl?.contentWindow)
                return void this.socketMessage(event.data);

            switch (event.data.type) {
                case 'setStandalone':
                    this.standaloneServerId = event.data.standaloneId;
                    this.standaloneUrl = event.data.standaloneUrl;
                    this.chatterFeatureEnabled = event.data.chatter;
                    this.debug = event.data.debug;
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
                    this.showRadio = event.data.visibility;
                    // if (this.inVehicle && this.radioPower) {
                    //     this.showMobileRadio = event.data.visibility;
                    //     this.showRadio = false;
                    // } else {
                    //     this.showMobileRadio = false;
                    //     this.showRadio = event.data.visibility;
                    // }
                    this.pttKeyName = event.data.pttKey;
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
                case 'inVehicle':
                    this.inVehicle = event.data.vehState;
                    break;
                case 'setUiPositions':
                    if (typeof event.data.data !== 'object') break;
                    this.positions = event.data.data;
                    break;
                case 'setSkins':
                case 'setCurrentSkin':
                    if (event.data.skins) // update available skins
                    if (event.data.skins !== this.selectSkinIds) {
                        this.selectSkinIds = event.data.skins;
                        this.updateAvailableSkins();
                    } else {
                        this.selectSkinIds = event.data.skins;
                    }
                    if (event.data.skin) // update current ski
                        this.selectSkin(event.data.skin);
                    break;
                case 'chatterWait':
                    // this is received after we sent chatterNeedsInput
                    // the event means we now have NUI focus, so we can set this.chatterNeedsInputHelp and wait for input
                    console.log('chatterWait from FiveM');
                    if (this.chatterNeedsInput) this.chatterNeedsInputHelp = true;
                    break;
                case 'chatterFrequenciesUpdate':
                    if (!this.chatterEnabled) return;
                    this.sendToSocket({
                        type: 'set_scanner_freqs',
                        freqs: event.data.freqs,
                    })
                    break;
                case 'chatterCameraUpdate':
                    if (!this.chatterEnabled) return;
                    this.sendToSocket({
                        type: 'set_audio_listener_orientation',
                        coord: event.data.coord,
                        forward: event.data.forward,
                        up: event.data.up
                    });
                    break;
                case 'chatterSourcesUpdate':
                    if (!this.chatterEnabled) return;
                    this.sendToSocket({
                        type: 'set_audio_source_positions',
                        sources: event.data.sources,
                    });
                    break;
                default:
                    break;
            }
        });
        // update the gamestate with an interval
        setInterval(this.updateGamestate.bind(this), 2500);

        this.postClient({ type: 'ready' });
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
                if (e.preventDefault) e.preventDefault();
                this.sendToSocket({ type: 'ptt', state: type === 'keydown' });
            }

            if (type !== 'keyup') return;
            switch (e.code) {
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
                    this.debug && this.debugNudgeSkinProperty(e);
                    break;
                default:
                    break;
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
        hideRadio(forceful) {
            this.postClient({ type: 'hide', force: forceful });
        },
        notifyPlayer(message, ignorestate) {
            if (this.radioPower || ignorestate) this.postClient({ type: "notify", message: message });
        },
        updateGamestate() {
            this.sendToSocket({
                type: "set_gamestate",
                state: this.$store.state.gamestate
            });
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
                    this.$store.commit('setConnected', this.radioPower);
                    this.$store.commit('setRadioConfig', event.config);
                    break;
                case "radio_disconnected":
                    this.$store.commit('setConnected', false);
                    break;
                case 'config_updated':
                    this.$store.commit('setRadioConfig', event.config);
                    break;
                case 'state_updated':
                    this.$store.commit('setRadioState', event.state);
                    if (this.radioPower)
                        this.postClient({ type: 'stateUpdated', state: event.state });
                    break;
                case 'mic_status':
                    this.postClient({type: 'talking', talking: event.micOpen});
                    break;
                case 'set_skin':
                    this.selectSkin(event.skinId || 'default');
                    break;
                case 'reposition':
                    this.dragMode = true;
                    break;
                case 'chatter_needs_input':
                    console.log('chatter_needs_input from standalone');
                    this.onStandaloneChatterLoad();
                    break;
                case 'chatter_init':
                    console.log('chatter_init from standalone');
                    this.postClient({ type: 'chatterInitialized' });
                    this.chatterNeedsInput = false;
                    this.chatterNeedsInputHelp = false;
                    break;
            }
        },
        sendToSocket(data) {
            if (frameEl) frameEl.contentWindow.postMessage(data, '*');
            // else console.warn("frameEl does not exist, but tried to send message", data);
        },
        updateAvailableSkins() {
            this.sendToSocket({ type: 'skin_options', options: this.selectSkinOptions(), current: this.curSkin?.id })
        },
        buttonPanic() {
            this.notifyPlayer("Radio: ~r~Panic Pressed!");
            this.postClient({
                type: "panic"
            });
        },
        buttonHome() {
            if (this.$refs.standaloneFrame.length === 0) return;
            this.$refs.standaloneFrame[0].flush(true);
            this.postClient({
                type: "home"
            });
        },
        buttonPrev() {
            if (!this.$store.state.connected)
                return void this.notifyPlayer("Radio: ~r~Not Connected")
            if (this.$store.getters.sublvl == 0)
                return void this.notifyPlayer("Radio: ~r~Button Disabled (Free Mode)")
            this.notifyPlayer("Radio: ~y~Prev Preset");
            this.prevPreset();
        },
        buttonNext() {
            if (!this.$store.state.connected)
                return void this.notifyPlayer("Radio: ~r~Not Connected")
            if (this.$store.getters.sublvl == 0)
                return void this.notifyPlayer("Radio: ~r~Button Disabled (Free Mode)")
            this.notifyPlayer("Radio: ~y~Next Preset");
            this.nextPreset();
        },
        buttonPower() {
            this.radioPower = !this.radioPower;
            this.chatterNeedsInput = false;
            this.$store.state.gamestate.radio_powered = this.radioPower;
            this.postClient({
                type: 'power',
                power: this.radioPower
            });
            this.sendToSocket({
                type: 'power',
                power: this.radioPower
            });
            this.notifyPlayer("Radio: " + (this.radioPower ? "~g~On~g~" : "~r~Off~r~"), true);
        },
        onStandaloneLoad() {
            setTimeout(() => {
                this.updateAvailableSkins();
                this.updateGamestate();
            }, 1000);
        },
        onStandaloneChatterLoad() {
            this.chatterNeedsInput = true;

            // constantly keep the frame in focus until it has been interacted with
            const interval = setInterval(() => {
                if (this.chatterNeedsInput) return void frameEl.contentWindow.focus();
                clearInterval(interval);
                this.$el.focus();
            }, 100)
            this.postClient({ type: 'chatterNeedsInput' });
        }
    }
};
</script>

<style scoped>
.appcontainer {
    overflow: hidden;
}


.top-instructions {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;

    display: flex;
    justify-content: center;
}

.top-instructions>* {
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
