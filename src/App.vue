<template>
    <div class="appcontainer" :class="{ debug: debug.enabled, help }">
        <div class="top-instructions">
            <div v-if="dragMode">
                Click and drag to move the components.
                Hold <code>CTRL</code> to resize.
                Press <code>ESC</code> to save.
            </div>
            <div v-else-if="emergencyCall.open && emergencyCall.showHelpText" style="display: flex; flex-direction: column; align-items: center">
                <div>
                    You are in an emergency call. Use <code>{{ emergencyCallCommand }}</code> to end it
                </div>
                <div v-if="emergencyCall.peers.length > 0" style="margin-top: 0.5rem">
                    <span style="color:#5d8ee8">Dispatchers with you:</span>
                    <div v-for="peer in emergencyCall.peers" :key="peer.id">
                        {{ peer.name }}
                    </div>
                </div>
                <div v-else style="color:orange">Waiting for dispatcher...</div>
            </div>
        </div>

        <!-- SKIN DEBUG MENU -->
        <div
            v-if="activeFrames.length > 0 && debug.enabled && debug.skinMenuExpanded"
            class="label-on-top skin-debug-menu"
            @keydown.prevent
            @keyup.prevent
        >
            <div style="display:flex;align-items:center;gap:8px">
                <h1>Sonoran Radio Skin Debug Menu</h1>
                <button @click="debug.skinMenuExpanded = false">&times;</button>
            </div>
            <!-- Options for changing/selecting the frame to modify -->
            <div>
                <h2>Choose Skin/Frame</h2>
                <select :value="curSkin?.id" @change="selectSkin($event.target.value, true)">
                    <option disabled value="">Select Skin</option>
                    <option v-for="skinId in selectSkinIds" :key="skinId" :value="skinId">
                        {{ skinId }}
                    </option>
                </select>
                <select v-model="debug.frameIndex">
                    <option disabled value="">Select Frame</option>
                    <option v-for="(frame, i) in (curSkin?.frames ?? [])" :key="frameKey(frame)" :value="i">
                        {{ frame.type }}
                    </option>
                </select>
                <label>
                    <input v-model="debug.frameShown" type="checkbox" />
                    <span>Show Frame</span>
                </label>
                <label>
                    <input v-model="dragMode" type="checkbox" />
                    <span>Move/Resize</span>
                </label>
            </div>
            <!-- Options for selecting a frame component, then moving it -->
            <div style="display:flex;gap:10px">
                <div>
                    <h2>Choose Component</h2>
                    <label v-for="fc in debugFrameComponentOptions" :key="fc.path.join('-')" class="radio-option">
                        <input v-model="debug.frameComponentPath" type="radio" :value="fc.path" />
                        <span>{{ fc.label }}</span>
                    </label>
                </div>
                <div>
                    <h2>Move Component</h2>
                    <adjust-buttons @action="debugMoveFrameComponent" />
                    <code><b>TIP</b>: Use arrow keys</code>

                    <h2>Resize Component</h2>
                    <adjust-buttons @action="debugResizeFrameComponent" />
                    <code><b>TIP</b>: Use CTRL + arrow keys</code>
                </div>
            </div>
            <div>
                <h2>Component Properties</h2>
                <pre v-if="debugFrameComponent">{{ debugFrameComponent }}</pre>
                <pre v-else>invalid component</pre>
                <button style="margin-top:10px" @click="debugSaveSkin">Save skin.json</button>
            </div>
        </div>
        <div v-else-if="activeFrames.length > 0 && debug.enabled" class="skin-debug-menu">
            <button @click="debug.skinMenuExpanded = true" style="opacity:0.25">&#x2C5;</button>
        </div>

        <!-- radio iframe for emergency calls -->
        <standalone-frame
            v-if="emergencyCallEnabled"
            ref="standaloneFrame"
            :server-id="standaloneServerId"
            :url="standaloneUrl"
            :query="{ roomId: standaloneRoomId, displayName: emergencyCall.name }"
            feature="911"
        />
        <!-- radio iframe for nearby chatter -->
        <standalone-frame
            v-if="chatterEnabled"
            ref="standaloneFrame"
            :server-id="standaloneServerId"
            :url="standaloneUrl"
            :query="{ roomId: standaloneRoomId }"
            feature="chatter"
        />

        <draggable-box
            v-for="frame in activeFrames"
            :key="frameKey(frame)"
            class="radio-frame"
            :drag-enabled="dragMode"
            :value="positions[frameKey(frame)] || defaultPositions[frame.type]"
            @input="$set(positions, frameKey(frame), $event)"
        >
            <skin-body-img v-if="frame.body" :skin-id="curSkin.id" :body-skin="frame.body" />

            <skin-body-component v-if="frame.screen" :bounds="frame.screen">
                <primary-screen :on="radioPower">
                    <standalone-frame
                        v-if="radioPower && standaloneServerId && !dragMode"
                        ref="standaloneFrame"
                        :server-id="standaloneServerId"
                        :url="standaloneUrl"
                        :query="{ roomId: standaloneRoomId, screen: frame.screen.style }"
                        iframe-persistent
                    />
                </primary-screen>
            </skin-body-component>

            <skin-body-component v-if="frame.miniScreen" :bounds="frame.miniScreen">
                <mini-screen v-if="radioPower" />
            </skin-body-component>
            <skin-body-component v-if="frame.scannerScreen" :bounds="frame.scannerScreen">
                <scanner-screen v-if="scannerMenu.state && scannerMenu.state.powered" :state="scannerMenu.state" />
            </skin-body-component>

            <skin-body-component v-for="(ctrl, i) in frame.controls" :key="i" :bounds="ctrl">
                <button class="radio-control" v-on="ctrl.events"></button>
                <code
                    v-if="debug || help"
                    class="label-on-top"
                    :class="{ 'hack': ['next', 'next_preset', 'scanner_next'].includes(ctrl.action) }"
                >{{ ctrl.action }}</code>
            </skin-body-component>
        </draggable-box>
    </div>
</template>

<script>
import SkinBodyImg from './components/skin/BodyImage.vue'
import SkinBodyComponent from './components/skin/BodyComp.vue'
import DraggableBox from './components/util/DraggableBox.vue'
import AdjustButtons from './components/util/AdjustButtons.vue'
import MiniScreen from './components/MiniScreen.vue'
import ScannerScreen from './components/ScannerScreen.vue'
import Screen from './components/Screen.vue'
import StandaloneFrame, {
    getFrameEl as getRadioFrameEl,
    removePersistentFrame as removeRadioFrame
} from './components/StandaloneFrame.vue'
import scannerPng from './assets/scanner.png'

export default {
    components: {
        SkinBodyImg,
        SkinBodyComponent,
        DraggableBox,
        AdjustButtons,
        MiniScreen,
        ScannerScreen,
        PrimaryScreen: Screen,
        StandaloneFrame,
    },
    data: () => {
        return {
            debug: {
                enabled: false,
                skinMenuExpanded: false,
                frameIndex: 0,
                frameShown: false,
                frameComponentPath: ['screen']
            },
            help: false,
            standaloneServerId: null,
            standaloneRoomId: null,
            standaloneUrl: null,
            pttKeyName: null,

            showRadio: false,
            showTopRadio: false,
            radioPower: false,
            escapeMode: localStorage.getItem("escape_mode") || "keep",
            nextPrevMode: 'preset',
            inVehicleClass: -1,
            towerQuality: 1.0,

            dragMode: false,
            defaultPositions: {
                portable: [0, 0, 16],
                vehicle: [0, 0, 16],
                hud: [400, 0, 16],
                scanner: [0, 0, 16],
            },
            positions: {},

            chatterFeatureEnabled: false,
            emergencyCall: {
                open: false,
                name: 'Guest',
                peers: [],
                state: null,
                cmd: '911',
                showHelpText: true,
            },
            scannerMenu: {
                open: false,
                id: null,
                state: null,
            },

            // promises of queried skin data (so we don't query twice)
            // Record<string, Promise<SkinData> | SkinData>
            skinCache: {},
            selectSkinIds: [], // list of skin ids that can be selected
            curSkin: null,
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
        setInterval(() => this.loop20(), 20000);
        this.selectSkin('default', true);

        window.addEventListener('message', (event) => {
            if (event.data.type === 'keyup' || event.data.type === 'keydown')
                return void this.onKeyPressed(event.data, event.data.type);

            // route messages from iframes to their handlers
            if (event.source === getRadioFrameEl('radio')?.contentWindow)
                return void this.onRadioFrameEvent(event.data);
            else if (event.source === getRadioFrameEl('chatter')?.contentWindow)
                return void this.onChatterFrameEvent(event.data);
            else if (event.source === getRadioFrameEl('911')?.contentWindow)
                return void this.onEmergencyCallFrameEvent(event.data);
            else if (event.source?.frameElement)
                return console.warn('unknown message event source', event.source, event);

            // messages not coming from an iframe are coming from the client
            this.onClientEvent(event.data);
        });

        this.postClient({ type: 'ready' });
    },
    computed: {
        radioVisible() {
            return this.showRadio || (this.escapeMode === 'transmit_only' && this.$store.state.talking);
        },
        activeRadioFrame() {
            if (!this.curSkin || !this.radioVisible) return null;
            const first = this.curSkin.frames[0];

            // find portable frame, or return first frame if not found
            if (this.inVehicleClass === -1)
                return this.curSkin.frames.find(x => x.type === 'portable') ?? first;

            // since inVehicleClass !== -1, we are in a vehicle and need to find the appropriate frame
            return (
              // find vehicle frame with class whitelisted
              this.curSkin.frames.find(
                (x) =>
                  x.type === "vehicle" &&
                  Array.isArray(x.vehicleClasses) &&
                  x.vehicleClasses.includes(this.inVehicleClass),
              ) ??
              // find regular vehicle frame
              this.curSkin.frames.find((x) => x.type === "vehicle") ??
              // use first frame because none were found
              first
            );
        },
        activeFrames() {
            if (!this.curSkin) return []; // no skin for the frames

            const getFrame = (type) => {
                const find = this.curSkin.frames.find(x => x.type === type)
                if (find) return find;
                const first = this.curSkin.frames[0];
                return first;
            };

            let frames = [];
            // if a frame is forcefully shown, then make it the first active frame
            if (this.debug.frameShown) {
                const frame = this.curSkin.frames[this.debug.frameIndex];
                if (frame) frames.push(frame);
            }

            if (this.scannerFrame) frames.push(this.scannerFrame);
            if (this.activeRadioFrame) frames.push(this.activeRadioFrame);
            if (this.showTopRadio) frames.push(getFrame('hud'));

            // dedupe frames by type
            frames = frames.filter((frame, i) => frames.findIndex((x) => x.type === frame.type) === i);

            const ACTIONS = {
                'power': this.buttonPower,
                'next': this.buttonNext,
                'prev': this.buttonPrev,
                // below two are only included for legacy support
                'next_preset': this.buttonNext,
                'prev_preset': this.buttonPrev,
                'panic': this.buttonPanic,
                'home': this.refreshScreen,
                'hide': () => this.escapeRadio(true),

                'scanner_power': this.scannerPower,
                'scanner_next': () => this.scannerAdvChannel(1),
                'scanner_prev': () => this.scannerAdvChannel(-1),
            };
            return frames.map((frame) => ({
                ...frame,
                controls: frame.controls.map((ctrl) => ({
                    ...ctrl,
                    events: {
                        click: (e) => e.button === 0 && ACTIONS[ctrl.action](e), // lmb
                        contextmenu: (e) => e.button === 2 && ACTIONS[ctrl.action](e), // rmb
                    }
                })),
            }));
        },
        debugFrameComponentOptions() {
            const frame = this.curSkin?.frames[this.debug.frameIndex];
            if (!frame) return [];

            const components = [];
            if (frame.screen) components.push({ path: ['screen'], label: 'screen' });
            if (frame.miniScreen) components.push({ path: ['miniScreen'], label: 'miniScreen' })
            frame.controls.forEach((control, i) =>
                components.push({ path: ['controls', i], label: `controls,${control.action}` })
            );
            return components;
        },
        debugFrameComponent() {
            let prop = this.curSkin?.frames[this.debug.frameIndex];
            if (!prop) return null;
            for (const key of this.debug.frameComponentPath) prop = prop[key];
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
        },
        emergencyCallEnabled() {
            return this.emergencyCall.open && !!this.standaloneServerId;
        },
        emergencyCallCommand() {
            const formatted = /\s/.test(this.emergencyCall.cmd) ? `"${this.emergencyCall.cmd}"` : this.emergencyCall.cmd;
            return `/radio ${formatted}`;
        },
        peersTalking() {
            const peersTalking = [...this.$store.state.peersTalking];
            return peersTalking.sort((a, b) => a.displayName - b.displayName)
        },
        isPanicking() {
            const myState = this.$store.state.radioState;
            if (!myState) return undefined;
            else return !!myState.panic;
        },
        internalEmergencyCallOpen() {
            return this.emergencyCall.open;
        },
        internalEmergencyCallDispatchers() {
            return this.emergencyCall.peers.map(x => x.name);
        },
        scannerFrame() {
            if (!this.scannerMenu.open) return null;
            const imageUrl = new URL(scannerPng, window.location.href);
            const frame = {
                type: 'scanner',
                key: 'scanner',
                body: { image: imageUrl.toString(),  width: 25 },
                controls: [
                    {
                        action: 'scanner_power',
                        bottom: 5.25,
                        right: 2.75,
                        width: 1.5,
                        height: 1.5,
                    },
                    {
                        action: 'scanner_prev',
                        bottom: 7.5,
                        right: 6.5,
                        width: 2.5,
                        height: 5.5,
                    },
                    {
                        action: 'scanner_next',
                        bottom: 7.5,
                        right: 4,
                        width: 2.5,
                        height: 5.5,
                    },
                ],
                scannerScreen: {
                    top: 6.25,
                    height: 4.5,
                    left: 4.5,
                    right: 4.5,
                    zIndex: 25,
                },
            };
            return frame;
        }
    },
    watch: {
        dragMode(newMode) {
            if (newMode) return; // only save when dragMode is disabled
            // save the positions by sending them back to the client
            this.postClient({
                type: 'setUiPositions', data: this.positions
            });
        },
        skinNames() {
            this.updateAvailableSkins();
        },
        isPanicking(status) {
            this.postClient({
                type: "panic",
                status: status,
            });
        },
        internalEmergencyCallOpen(status) {
            this.postClient({
                type: 'emergencyCallStatus',
                status,
            });
        },
        internalEmergencyCallDispatchers(dispatcherNames) {
            this.postClient({
                type: 'emergencyCallDispatcher',
                dispatcherNames,
            })
        }
    },
    methods: {
        async postClient(data, route = "/data") {
            const url = new URL(route, `https://${GetParentResourceName()}`);
            const res = await fetch(url.toString(), {
                method: "POST",
                body: JSON.stringify(data),
            });
            if (res.status !== 200)
                return console.error(`failed request with code: ${res.status}`);

            const msg = await res.json();
            if (msg !== "OK") throw new Error(`failed request with message: ${data}`);
        },
        onClientEvent(event) {
            switch (event.type) {
                case 'setStandalone':
                    this.standaloneServerId = event.standaloneId;
                    this.standaloneRoomId = event.roomId;
                    this.standaloneUrl = event.standaloneUrl;
                    this.chatterFeatureEnabled = event.chatter;
                    this.debug.enabled = event.debug;
                    break;
                case 'power':
                    this.radioPower = event.power !== undefined ? !!event.power : !this.radioPower;
                    this.postClient({
                        type: 'power',
                        power: this.radioPower
                    });
                    break;
                case 'setVisible':
                    this.showRadio = event.visibility;
                    this.pttKeyName = event.pttKey;
                    break;
                case 'reset':
                    localStorage.clear();
                    this.positions = {};
                    this.escapeMode = 'keep';
                    this.selectSkin('default');
                case 'refresh':
                    this.refreshScreen();
                    break;
                case 'openScanner':
                    this.scannerMenu.open = true;
                    this.scannerMenu.id = event.id;
                    this.scannerMenu.state = event.state;
                    break;
                case 'setEmergencyCall':
                    this.setEmergencyCall(event.enabled, event.displayName, event.callCommand, event.showHelpText);
                    break;
                case 'ptt':
                    if (!this.radioPower) return;
                    this.postRadioFrame({ type: 'ptt', state: event.state });
                    break;
                case 'setVolume':
                    this.postRadioFrame({ type: 'set_global_volume', volume: Math.min(event.volume, 250) });
                    this.postChatterFrame({ type: 'set_global_volume', volume: Math.min(event.volume, 250) });
                    this.postEmergencyCallFrame({ type: 'set_global_volume', volume: Math.min(event.volume, 250) });
                    break;
                case 'setTowerQuality':
                    this.towerQuality = event.quality;
                    this.updateGamestate();
                    break;
                case 'radioHud':
                    this.showTopRadio = event.size !== 'off';
                    break;
                case 'togglePrimaryChannel':
                    this.postRadioFrame({ type: 'toggle_primary_channel', channelId: event.id });
                    break;
                case 'toggleScanChannel':
                    this.postRadioFrame({ type: 'toggle_scan_channel', channelId: event.id });
                    break;
                case 'selectScanList':
                    this.postRadioFrame({ type: 'select_scan_list', scanListId: event.id });
                    break;
                case 'pushButton':
                    switch (event.button) {
                        case 'prev':
                            this.buttonPrev();
                            break;
                        case 'next':
                            this.buttonNext();
                            break;
                        case 'group_next':
                            this.nextGroup();
                            break;
                        case 'group_prev':
                            this.prevGroup();
                            break;
                        case 'vol_up':
                            this.postRadioFrame({ type: 'notch_vol_up' });
                            break;
                        case 'vol_down':
                            this.postRadioFrame({ type: 'notch_vol_down' });
                            break;
                        case 'power':
                            this.buttonPower();
                            break;
                        case 'panic':
                            this.buttonPanic();
                            break;
                    }
                    break;
                case 'goToPreset':
                    this.goToPreset(event.preset);
                    break;
                case 'callUpdate':
                    // CAD call update (NOT EMERGENCY CALL)
                    this.postRadioFrame({ type: 'set_call', call: event.call });
                    break;
                case 'unitStatus':
                    this.$store.commit('setUnitStatus', event.status);
                    break;
                case 'inVehicle':
                    this.inVehicleClass = event.vehClass;
                    break;
                case 'noRadioItem':
                    if (this.radioPower) this.buttonPower();
                    if (this.showRadio) this.escapeRadio(true);
                    break;
                case 'setUiPositions':
                    if (typeof event.data !== 'object') break;
                    this.positions = event.data;
                    break;
                case 'setSkins':
                case 'setCurrentSkin':
                    if (event.skins) // update available skins
                    if (event.skins !== this.selectSkinIds) {
                        this.selectSkinIds = event.skins;
                        this.updateAvailableSkins();
                    } else {
                        this.selectSkinIds = event.skins;
                    }
                    if (event.skin) this.selectSkin(event.skin);
                    break;
                case 'chatterCameraUpdate':
                    this.postChatterFrame({
                        type: 'set_audio_listener_orientation',
                        coord: event.coord,
                        forward: event.forward,
                        up: event.up
                    });
                    break;
                case 'chatterSourcesUpdate':
                    this.postChatterFrame({
                        type: 'set_audio_source_positions',
                        sources: event.sources,
                        isMuffled: event.isMuffled,
                        isSpatial: event.isSpatial,
                        target: event.target,
                    });
                    this.postChatterFrame({
                        type: 'set_scanner_channels',
                        channelIds: event.channelIds,
                    });
                    break;
                case 'get_connected_users':
                    this.postRadioFrame({
                        type: 'get_connected_users',
                    });
                    break;
                case 'siren_toggle':
                    this.postRadioFrame({
                        type: 'siren_toggle',
                        state : event.state
                    });
                    break;
                case 'set_display_name':
                    this.postRadioFrame({
                        type: 'set_display_name',
                        name: event.name
                    })
                    break;
                case 'toggle_background_audio':
                    this.postRadioFrame({
                        type: 'toggle_background_audio',
                        start: event.start,
                        trackId: event.trackId,
                        volume: event.volume,
                    });
                    break;
            }
        },

        postRadioFrame(data) {
            getRadioFrameEl('radio')?.contentWindow.postMessage(data, '*');
        },
        onRadioFrameEvent(event) {
            switch (event.type) {
                case "radio_connected":
                    console.log('radio connected');
                    this.$store.commit('setConnected', { connected: true, identity: event.identity });
                    this.$store.commit('setRadioConfig', event.config);
                    this.onStandaloneConnected();
                    break;
                case "radio_disconnected":
                    this.$store.commit('setConnected', { connected: false });
                    break;
                case "pending_approval":
                    this.postClient({ type: 'radioNeedsAuth', accId: event.accId });
                    break;
                case "display_error":
                    this.notifyPlayer(`~r~Radio Error: ~s~${event.error}`);
                    break;
                case 'config_updated':
                    this.$store.commit('setRadioConfig', event.config);
                    break;
                case 'state_updated':
                    // include the identity in the state (used for audio ducking)
                    const state = {...event.state, identity: this.$store.state.identity};
                    this.$store.commit('setRadioState', state);
                    this.postClient({ type: 'stateUpdated', state });
                    break;
                case 'mic_status':
                    this.$store.commit('setRadioTalking', event.micOpen);
                    this.postClient({ type: 'talking', talking: event.micOpen });
                    break;
                case 'peer_talk_status':
                    this.$store.commit('setPeerTalkStatus', event.peer);
                    break;
                case 'set_skin':
                    this.selectSkin(event.skinId || 'default');
                    break;
                case 'set_escape_mode':
                    this.setEscapeMode(event.mode);
                    break;
                case 'reposition':
                    this.dragMode = true;
                    break;
                case 'toggle_background_audio_confirm':
                    this.postClient({
                        type: 'toggle_background_audio_confirm',
                        start: event.start,
                        trackId: event.trackId
                    });
                    break;
            }
        },
        postChatterFrame(data) {
            getRadioFrameEl('chatter')?.contentWindow.postMessage(data, '*');
        },
        onChatterFrameEvent(event) {
            switch (event.type) {
                case 'radio_connected':
                    this.postClient({ type: 'chatterInit' });
                case 'config_updated':
                    this.$store.commit('setChatterConfig', event.config);
                    this.postClient({ type: 'setChatterConfig', config: event.config }, 'scanners');
                    break;
            }
        },
        postEmergencyCallFrame(data) {
            getRadioFrameEl('911')?.contentWindow.postMessage(data, '*');
        },
        onEmergencyCallFrameEvent(event) {
            switch (event.type) {
                case 'radio_connected':
                    this.emergencyCall.state = event.state;
                    this.postClient({ type: 'stateUpdatedEmergencyCall', state: event.state });
                    break;
                case "radio_disconnected":
                    // we were kicked on the radio, so end the call
                    this.setEmergencyCall(false);
                    break;
                case 'call_peers':
                    this.emergencyCall.peers = event.peers;
                    break;
                case "display_error":
                    this.notifyPlayer(`~r~Emergency Call Error: ~s~${event.error}`);
                    break;
            }
        },

        onKeyPressed(e, type) {
            if (type === 'keyup') {
                switch (e.code) {
                    case "Escape":
                        if (this.dragMode)
                            this.dragMode = false;
                        else
                            this.escapeRadio(false);
                        if (this.dragMode) {
                        } else {
                            this.escapeRadio(false);
                        }
                        break;
                    case 'ArrowUp':
                    case 'ArrowDown':
                    case 'ArrowLeft':
                    case 'ArrowRight':
                        if (!this.debug.enabled) break;
                        const dirs = {
                            'ArrowUp': 'up',
                            'ArrowDown': 'down',
                            'ArrowLeft': 'left',
                            'ArrowRight': 'right'
                        };
                        const dir = dirs[e.code];
                        if (!e.ctrlKey)
                            this.debugMoveFrameComponent(dir);
                        else
                            this.debugResizeFrameComponent(dir);
                        break;
                }
            }

            const matchesPtt = e.code === this.pttKeyName || (this.pttKeyName?.startsWith('SpecialKey.') && e.code === this.pttKeyName.split('.')[1]);
            if (matchesPtt && !e.repeat) {
                if (e.preventDefault) e.preventDefault();
                this.postRadioFrame({ type: 'ptt', state: type === 'keydown' });
            }
        },

        async querySkinNoCache(skinId) {
            const url = new URL(`https://cfx-nui-${GetParentResourceName()}/skins/${skinId}/skin.json`);
            const res = await fetch(url);
            const skinData = await res.json()

            skinData.id = skinId;
            skinData.configPath = url.pathname;
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
        selectSkin(skinId, temporary) {
            this.querySkin(skinId).then(skin => this.curSkin = skin);
            if (!temporary) this.postClient({ type: 'currentSkinUpdated', skin: skinId });
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
        frameKey(frame) {
            return [this.curSkin.id, frame.type, ...(frame.vehicleClasses ?? [])].join('-');
        },
        debugGetNudge(dir) {
            const NUDGE = 1 / 8;
            let w = 0;
            let h = 0;
            if (dir === 'up') h = -NUDGE;
            else if (dir === 'down') h = NUDGE;
            else if (dir === 'left') w = -NUDGE;
            else if (dir === 'right') w = NUDGE;
            return { w, h };
        },
        debugMoveFrameComponent(dir) {
            const prop = this.debugFrameComponent;
            if (!prop) return;

            const {w, h} = this.debugGetNudge(dir);
            if (prop.top !== undefined)
                this.$set(prop, 'top', prop.top + h);
            if (prop.bottom !== undefined)
                this.$set(prop, 'bottom', prop.bottom - h);
            if (prop.left !== undefined)
                this.$set(prop, 'left', prop.left + w);
            if (prop.right !== undefined)
                this.$set(prop, 'right', prop.right - w);
        },
        debugResizeFrameComponent(dir) {
            const prop = this.debugFrameComponent;
            if (!prop) return;

            const {w, h} = this.debugGetNudge(dir);
            if (prop.height !== undefined)
                this.$set(prop, 'height', prop.height - h);
            else if (prop.bottom !== undefined)
                this.$set(prop, 'bottom', prop.bottom + h);
            else if (prop.top !== undefined)
                this.$set(prop, 'top', prop.top - h);

            if (prop.width !== undefined)
                this.$set(prop, 'width', prop.width + w);
            else if (prop.right !== undefined)
                this.$set(prop, 'right', prop.right - w);
            else if (prop.left !== undefined)
                this.$set(prop, 'left', prop.left + w);
        },
        debugSaveSkin() {
            const configPath = this.curSkin.configPath;
            // shallow clone curSkin to delete properties
            const skinJson = {...this.curSkin};
            delete skinJson['id'];
            delete skinJson['configPath'];
            this.postClient({
                type: 'saveSkinConfig',
                configPath: configPath.substring(1), // get rid of trailing slash
                config: JSON.stringify(skinJson, null, 2)
            });
        },

        escapeRadio(hide) {
            this.postClient({ type: 'escape' });
            if (hide || this.escapeMode !== 'keep') this.showRadio = false;
            if (this.scannerMenu.open) {
                this.scannerMenu.open = false;
                this.postClient({ type: 'saveScanner', id: this.scannerMenu.id }, 'scanners');
            }

            // notify player on how to hide radio if this is the first time
            const LS_KEY = 'hide_portable_hint_seen';
            if (hide || this.escapeMode !== 'keep' || localStorage.getItem(LS_KEY)) return;
            this.notifyPlayer('~g~HINT~s~: Use ~y~/radio hide~s~ or press the ~p~purple button~s~ to hide the radio');
            localStorage.setItem(LS_KEY, 'true');
        },
        setEscapeMode(mode) {
            this.escapeMode = mode;
            localStorage.setItem("escape_mode", mode);
            this.updateEscapeMode();
        },
        updateEscapeMode() {
            this.postRadioFrame({ type: 'escape_mode', mode: this.escapeMode });
        },

        notifyPlayer(message) {
            this.postClient({ type: "notify", message: message });
        },
        updateGamestate() {
            this.postRadioFrame({
                type: "set_gamestate",
                state: { tower_quality: this.towerQuality },
            });
        },
        nextPreset() {
            this.postRadioFrame({type: 'group_preset_next'});
        },
        prevPreset() {
            this.postRadioFrame({type: 'group_preset_prev'});
        },
        nextGroup() {
            this.postRadioFrame({type: 'group_next'});
        },
        prevGroup() {
            this.postRadioFrame({type: 'group_prev'});
        },
        updateAvailableSkins() {
            this.postRadioFrame({ type: 'skin_options', options: this.selectSkinOptions(), current: this.curSkin?.id })
        },
        refreshScreen() {
            // Get all <standalone-frame> references (emergency call frame, chatter frame, radio viewer frame)
            const standaloneFrames = this.$refs.standaloneFrame;
            if (Array.isArray(standaloneFrames)) {
                // Multiple frames: Iterate through each
                standaloneFrames.forEach(frame => frame.flush(true));
            } else if (standaloneFrames) {
                // Single frame: Directly call flush
                standaloneFrames.flush(true);
            } else {
                console.warn('No standaloneFrame references found.');
            }
            this.postClient({ type: "refreshScreen" });
        },
        buttonPanic() {
            if (this.isPanicking === undefined) return;

            if (!this.isPanicking)
                this.notifyPlayer("Radio: ~r~Panic Pressed!");
            else
                this.notifyPlayer('Radio: ~r~Stopped Panicking');
            this.postRadioFrame({ type: 'set_panicking', panicking: !this.isPanicking });
        },
        changeNextPrevMode() {
            this.nextPrevMode = this.nextPrevMode === 'preset' ? 'group' : 'preset';
            if (this.nextPrevMode === 'preset')
                this.notifyPlayer(`Radio: ~y~Now selecting channels`);
            else
                this.notifyPlayer(`Radio: ~y~Now selecting groups`);
        },
        buttonPrev(e) {
            if (!this.$store.state.connected)
                this.notifyPlayer("Radio: ~r~Not Connected")
            else if (e?.button === 2) {
                this.changeNextPrevMode();
            } else if (this.nextPrevMode === 'preset') {
                this.notifyPlayer("Radio: ~y~Previous channel");
                this.prevPreset();
            } else {
                this.notifyPlayer("Radio: ~y~Previous group");
                this.prevGroup();
            }
        },
        buttonNext(e) {
            if (!this.$store.state.connected)
                this.notifyPlayer("Radio: ~r~Not Connected")
            else if (e?.button === 2) {
                this.changeNextPrevMode();
            } else if (this.nextPrevMode === 'preset') {
                this.notifyPlayer("Radio: ~y~Next channel");
                this.nextPreset();
            } else {
                this.notifyPlayer("Radio: ~y~Next group");
                this.nextGroup();
            }
        },
        buttonPower() {
            this.radioPower = !this.radioPower;
            this.postClient({
                type: 'power',
                power: this.radioPower
            });
            this.notifyPlayer("Radio: " + (this.radioPower ? "~g~On" : "~r~Off"));

            if (this.radioPower) return;
            // we need to remove the frame to "disconnect" from the radio
            // normally the iframe persists because it is only hidden, not disconnected
            this.$nextTick(() => {
                removeRadioFrame('radio');
            });
        },
        scannerPower() {
            if (!this.scannerMenu.state) this.scannerMenu.state = {};
            this.scannerMenu.state.powered = !this.scannerMenu.state.powered;
            this.scannerMenu.state.channelId = this.$store.getters.chatterDefaultProfileId;
            this.postClient({ type: 'setScanner', id: this.scannerMenu.id, state: this.scannerMenu.state }, 'scanners');
        },
        scannerAdvChannel(offset) {
            const profiles = this.$store.getters.chatterProfilesSorted.filter(x => x.visibility === 'public');
            const chId = this.scannerMenu.state.channelId || this.$store.getters.chatterDefaultProfileId;
            const idx = profiles.findIndex(x => x.id === chId) || 0;

            const nextIdx = (idx + offset + profiles.length) % profiles.length;
            this.scannerMenu.state.channelId = profiles[nextIdx].id;
            this.postClient({ type: 'setScanner', id: this.scannerMenu.id, state: this.scannerMenu.state }, 'scanners');
        },
        setEmergencyCall(enabled, displayName, cmd, showHelpText) {
            const enable = enabled === 'toggle' ? !this.emergencyCall.open : !!enabled;
            this.emergencyCall.open = enable;
            if (displayName) this.emergencyCall.name = displayName;
            if (cmd) this.emergencyCall.cmd = cmd;
            if (showHelpText != null) this.emergencyCall.showHelpText = showHelpText;
            if (!enable) {
                // reset the emergency call state
                this.emergencyCall.peers = [];
                this.emergencyCall.state = null;
            }
            this.postClient({ type: 'emergencyCall', enabled: enable })
        },
        loop20() {
            // keep pushing stateUpdated every 20s
            // NOTE: chatter won't work without this (the server clears stale data after 30s of no update)
            if (this.emergencyCallEnabled) {
                const state = this.emergencyCall.state;
                if (state) this.postClient({ type: 'stateUpdatedEmergencyCall', state });
            } else if (this.radioPower) {
                const state = this.$store.state.radioState;
                if (state) this.postClient({ type: 'stateUpdated', state });
            }
        },
        onStandaloneConnected() {
            this.updateGamestate();
            this.updateAvailableSkins();
            this.updateEscapeMode();
            this.postClient({
                type: 'radioConnected',
                config: this.$store.state.radioConfig
            });
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

.skin-debug-menu {
    display: inline-block;
    padding: 1rem;
}
.skin-debug-menu .radio-option {
    display: block;
    margin-bottom: 6px;
}

.debug .radio-frame {
    outline: 3px solid red;
}

.debug .radio-control,
.help .radio-control {
    outline: 2px solid green;
}
</style>
