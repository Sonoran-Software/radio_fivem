<template>
    <div class="appcontainer" :class="{ debug: debug.enabled, help }">
        <div class="top-instructions">
            <div v-if="dragMode">
                Click and drag to move the components.
                Hold <code>CTRL</code> to resize.
                Press <code>ESC</code> to save.
            </div>
            <div v-else-if="emergencyCall.showMicTroubleshooting" style="display: flex; flex-direction: column; align-items: center">
                <div>
                    Microphone troubleshooting is open. Press <code>ESC</code> to close it
                </div>
            </div>
            <div v-else-if="emergencyCall.status === 'open' && emergencyCall.showHelpText" style="display: flex; flex-direction: column; align-items: center">
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
            v-if="debug.enabled && debug.skinMenuExpanded"
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
                <select :value="curSkin?.id" @change="selectSkin($event.target.value)">
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
        <div v-else-if="debug.enabled && activeFrames.length > 0" class="skin-debug-menu">
            <button @click="debug.skinMenuExpanded = true" style="opacity:0.25">&#x2C5;</button>
        </div>

        <!-- radio iframe for emergency calls -->
        <div v-if="emergencyCall.status !== 'closed'" class="emergency-call-frame-shell">
            <standalone-frame
                ref="standaloneFrame"
                :server-id="standaloneServerId"
                :url="standaloneUrl"
                :query="{
                    guestToken: emergencyCall.token,
                    roomId: standaloneRoomId,
                    displayName: emergencyCall.name,
                }"
                :visible="emergencyCall.showMicTroubleshooting"
                feature="911"
            />
        </div>
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
                        :query="{
                            roomId: standaloneRoomId,
                            guestok: allowedGuest,
                        }"
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
                    v-if="debug.enabled || help"
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
import defaultScannerFrame from './assets/scannerFrame'

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
                frameComponentPath: ['screen']
            },
            help: false,
            standaloneServerId: null,
            standaloneRoomId: null,
            standaloneUrl: null,
            pttKeyName: null,
            pttActive: false,

            showRadio: false,
            showTopRadio: false,
            radioPower: false,
            escapeMode: "keep",
            nextPrevMode: 'preset',
            inVehicleClass: -1,
            towerQuality: 1.0,
            allowedGuest: false,

            isJammed : false,
            jammerStrength : 0.0,

            dragMode: false,
            defaultPositions: {
                portable: [0, 0, 16],
                vehicle: [0, 0, 16],
                hud: [400, 0, 16],
                scanner: [0, 0, 16],
            },
            positions: {},

            chatterFeatureEnabled: false,
            streamDeck: {
                healthUrl: 'http://127.0.0.1:39112/streamdeck/fivem/health',
                socketUrl: 'ws://127.0.0.1:39112/streamdeck/fivem/socket',
                healthPollMs: 5000,
                reconnectMs: 3000,
                healthTimer: null,
                reconnectTimer: null,
                socket: null,
                latestSnapshot: {
                    channels: [],
                    state: {
                        connected: false,
                        aiEnabled: false,
                        micOpen: false,
                        primaryChIds: [],
                        scannedChIds: [],
                        sfxVolume: 0,
                        agentGain: 0,
                    }
                },
            },
            emergencyCall: {
                status: 'closed', // closed, open, idle (for redial)
                token: '',
                name: 'Guest',
                peers: [],
                state: null,
                cmd: '911',
                showHelpText: true,
                showMicTroubleshooting: false,
            },
            scannerMenu: {
                open: false,
                id: 0,
                state: null,
                allowedProfileIds: [],
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
        this.startStreamDeckHealthPolling();

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
    beforeDestroy() {
        this.setPttState(false);
        this.stopStreamDeckHealthPolling();
        this.closeStreamDeckSocket();
    },
    computed: {
        radioVisible() {
            return this.showRadio || (this.escapeMode === 'transmit_only' && this.$store.state.talking);
        },
        activeRadioFrame() {
            if (!this.curSkin || !this.radioVisible) return null;

            if (this.inVehicleClass !== -1) {
                // we are in a vehicle, find the appropriate vehicle frame for this veh class
                const vehFrame = this.curSkin.frames.find(frame =>
                    frame.type === 'vehicle' &&
                    (!Array.isArray(frame.vehicleClasses) || frame.vehicleClasses.includes(this.inVehicleClass))
                );
                if (vehFrame) return vehFrame;
                // fallback to portable frame if vehFrame does not exist
            }

            // find portable frame, or return first frame if not found
            return this.curSkin.frames.find(x => x.type === 'portable') ?? this.curSkin.frames[0];
        },
        activeRadioScreenStyle() {
            return this.activeRadioFrame?.screen?.style === 'text' ? 'text' : 'modern';
        },
        activeScannerFrame() {
            if (!this.scannerMenu.open) return null;
            if (this.curSkin) {
                const frame = this.curSkin.frames.find(x => x.type === 'scanner');
                if (frame) return frame;
                // fallback to default scanner frame if not found
            }
            return defaultScannerFrame;
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
            if (this.debug.skinMenuExpanded) {
                // debug menu on, only show the currently debugged frame
                const frame = this.curSkin.frames[this.debug.frameIndex];
                if (frame) frames.push(frame);
            } else {
                // normal operation frame checks
                if (this.activeScannerFrame) frames.push(this.activeScannerFrame);
                if (this.activeRadioFrame) frames.push(this.activeRadioFrame);
                if (this.showTopRadio) frames.push(getFrame('hud'));
            }

            // dedupe frames by type
            frames = frames.filter((frame, i) => frames.findIndex((x) => x.type === frame.type) === i);

            const ACTIONS = {
                'power': this.buttonPower,
                'next': this.buttonNext,
                'prev': this.buttonPrev,
                'next_group': this.nextGroup,
                'prev_group': this.prevGroup,
                'vol_up': this.buttonVolUp,
                'vol_down': this.buttonVolDown,
                'panic': this.buttonPanic,
                'home': this.refreshScreen,
                'hide': () => this.escapeRadio(true),

                // below two are only included for legacy support
                'next_preset': this.buttonNext,
                'prev_preset': this.buttonPrev,

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
            return !!this.standaloneServerId;
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
            return this.emergencyCall.status === 'open';
        },
        internalEmergencyCallDispatchers() {
            return this.emergencyCall.peers.map(x => x.name);
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
        activeRadioScreenStyle() {
            this.updateRadioScreenStyle();
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
            if (typeof msg === 'string' && msg !== "OK") throw new Error(`failed request with message: ${data}`);
            return msg;
        },
        normalizeStreamDeckIds(ids) {
            if (!Array.isArray(ids)) return [];
            return ids
                .map((id) => Number(id))
                .filter((id) => Number.isFinite(id));
        },
        getStreamDeckDefaultSnapshot() {
            return {
                channels: [],
                state: {
                    connected: false,
                    aiEnabled: false,
                    micOpen: false,
                    primaryChIds: [],
                    scannedChIds: [],
                    sfxVolume: 0,
                    agentGain: 0,
                }
            };
        },
        buildStreamDeckSnapshot() {
            const radioConfig = this.$store.state.radioConfig;
            const radioState = this.$store.state.radioState;
            const profiles = Array.isArray(radioConfig?.profiles) ? radioConfig.profiles : [];
            const channels = profiles
                .map((profile) => {
                    const id = Number(profile?.id);
                    if (!Number.isFinite(id)) return null;
                    return {
                        id,
                        label: profile?.displayName || profile?.name || String(id),
                        groupId: Number.isFinite(Number(profile?.groupId)) ? Number(profile.groupId) : 0,
                        groupName: profile?.groupName || profile?.group || profile?.groupLabel || '',
                    };
                })
                .filter(Boolean);

            return {
                channels,
                state: {
                    connected: !!this.$store.state.connected,
                    aiEnabled: !!(radioState?.aiEnabled),
                    micOpen: !!this.$store.state.talking,
                    primaryChIds: this.normalizeStreamDeckIds(radioState?.primaryChIds),
                    scannedChIds: this.normalizeStreamDeckIds(radioState?.scannedChIds),
                    sfxVolume: Number.isFinite(Number(radioState?.sfxVolume)) ? Number(radioState.sfxVolume) : 0,
                    agentGain: Number.isFinite(Number(radioState?.agentGain)) ? Number(radioState.agentGain) : 0,
                }
            };
        },
        publishStreamDeckSnapshot(snapshot) {
            const nextSnapshot = snapshot || this.buildStreamDeckSnapshot();
            this.streamDeck.latestSnapshot = nextSnapshot;
            const socket = this.streamDeck.socket;
            if (!socket || socket.readyState !== WebSocket.OPEN) return;

            socket.send(JSON.stringify({
                type: 'streamdeck_snapshot',
                snapshot: nextSnapshot,
            }));
        },
        requestStreamDeckSnapshotFromRadio() {
            this.postRadioFrame({ type: 'streamdeck_snapshot_request' });
        },
        handleStreamDeckCommand(payload) {
            if (!payload || typeof payload.command !== 'string') return;
            this.postRadioFrame({
                type: 'streamdeck_command',
                payload,
            });
        },
        handleStreamDeckDesktopMessage(message) {
            if (!message || typeof message.type !== 'string') return;

            switch (message.type) {
                case 'hello':
                    this.publishStreamDeckSnapshot(this.buildStreamDeckSnapshot());
                    this.requestStreamDeckSnapshotFromRadio();
                    break;
                case 'streamdeck_command':
                    if (message.payload.command == "desktop.toggleRadio" || message.payload.command == "desktop.focusRadio") {
                        this.postClient({ type: 'toggleRadio' });
                    }
                    if (message.payload.command == 'desktop.connectedUsers') {
                        this.postClient({ type: 'toggleConnectedUsers' });
                    }
                    this.handleStreamDeckCommand(message.payload);
                    break;
                case 'streamdeck_snapshot':
                    if (message.snapshot) this.streamDeck.latestSnapshot = message.snapshot;
                    break;
                case 'streamdeck_snapshot_request':
                    this.publishStreamDeckSnapshot(this.buildStreamDeckSnapshot());
                    this.requestStreamDeckSnapshotFromRadio();
                    break;
            }
        },
        scheduleStreamDeckReconnect() {
            if (this.streamDeck.reconnectTimer) return;
            this.streamDeck.reconnectTimer = window.setTimeout(() => {
                this.streamDeck.reconnectTimer = null;
                this.connectStreamDeckSocket();
            }, this.streamDeck.reconnectMs);
        },
        closeStreamDeckSocket() {
            if (this.streamDeck.reconnectTimer) {
                window.clearTimeout(this.streamDeck.reconnectTimer);
                this.streamDeck.reconnectTimer = null;
            }

            const socket = this.streamDeck.socket;
            this.streamDeck.socket = null;
            if (!socket) return;

            socket.onopen = null;
            socket.onmessage = null;
            socket.onerror = null;
            socket.onclose = null;
            if (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)
                socket.close();
        },
        async pollStreamDeckHealth() {
            try {
                const response = await fetch(this.streamDeck.healthUrl);
                if (!response.ok) throw new Error(`health check failed with ${response.status}`);
                const health = await response.json();
                if (health?.ok) {
                    this.connectStreamDeckSocket();
                    return;
                }
            } catch (_err) {
                this.closeStreamDeckSocket();
            }
        },
        startStreamDeckHealthPolling() {
            if (this.streamDeck.healthTimer) return;
            this.pollStreamDeckHealth();
            this.streamDeck.healthTimer = window.setInterval(() => {
                this.pollStreamDeckHealth();
            }, this.streamDeck.healthPollMs);
        },
        stopStreamDeckHealthPolling() {
            if (!this.streamDeck.healthTimer) return;
            window.clearInterval(this.streamDeck.healthTimer);
            this.streamDeck.healthTimer = null;
        },
        connectStreamDeckSocket() {
            const existingSocket = this.streamDeck.socket;
            if (existingSocket && (existingSocket.readyState === WebSocket.OPEN || existingSocket.readyState === WebSocket.CONNECTING))
                return;

            const socket = new WebSocket(this.streamDeck.socketUrl);
            this.streamDeck.socket = socket;

            socket.onopen = () => {
                this.publishStreamDeckSnapshot(this.buildStreamDeckSnapshot());
                this.requestStreamDeckSnapshotFromRadio();
            };
            socket.onmessage = (event) => {
                try {
                    this.handleStreamDeckDesktopMessage(JSON.parse(event.data));
                } catch (error) {
                    console.error('Failed to parse Stream Deck desktop bridge message', error);
                }
            };
            socket.onerror = () => {
                this.scheduleStreamDeckReconnect();
            };
            socket.onclose = () => {
                if (this.streamDeck.socket === socket) this.streamDeck.socket = null;
                this.scheduleStreamDeckReconnect();
            };
        },
        onClientEvent(event) {
            switch (event.type) {
                case 'setConfig':
                    this.standaloneServerId = event.standaloneId;
                    this.standaloneRoomId = event.roomId;
                    this.standaloneUrl = event.standaloneUrl;
                    this.escapeMode = localStorage.getItem('escape_mode') || event.defaultEscapeMode || 'keep';
                    this.chatterFeatureEnabled = event.chatter;
                    this.debug.enabled = event.debug;
                    this.emergencyCall.name = event.displayName;
                    break;
                case 'setGuestAllowed':
                    this.allowedGuest = event.allowed;
                    break;
                case 'power':
                    if (event.power !== this.radioPower) this.buttonPower();
                    break;
                case 'setVisible':
                    this.showRadio = event.visibility;
                    this.pttKeyName = event.pttKey;
                    break;
                case 'reset':
                    localStorage.clear();
                    this.positions = {};
                    this.escapeMode = 'keep';
                    this.selectSkin(event.skin || 'default');
                case 'refresh':
                    this.refreshScreen();
                    break;
                case 'openScanner':
                    this.scannerMenu.open = true;
                    this.scannerMenu.id = event.id;
                    this.scannerMenu.state = event.state;
                    this.requestScannerProfilePerms();
                    break;
                case 'allowScannerProfiles':
                    this.scannerMenu.allowedProfileIds = event.profileIds;
                    break;
                case 'setEmergencyCall':
                    this.setEmergencyCall(event.enabled, event);
                    break;
                case 'ptt':
                    this.setPttState(event.state);
                    break;
                case 'setVolume':
                    this.postRadioFrame({ type: 'set_global_volume', volume: Math.min(event.volume, 250) });
                    this.postChatterFrame({ type: 'set_global_volume', volume: Math.min(event.volume, 250) });
                    this.postEmergencyCallFrame({ type: 'set_global_volume', volume: Math.min(event.volume, 250) });
                    break;
                case 'setTowerQuality':
                    this.towerQuality = event.quality;
                    this.isJammed = event.isJammed;
                    this.jammerStrength = event.jammerStrength;
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
                            this.buttonVolUp();
                            break;
                        case 'vol_down':
                            this.buttonVolDown();
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
                case 'cadCommunityUserId':
                    this.$store.commit('setCadCommunityUserId', event.communityUserId ?? null);
                    this.updateGamestate();
                    break;
                case 'inVehicle':
                    this.inVehicleClass = event.vehClass;
                    break;
                case 'noRadioItem':
                    if (this.radioPower) this.buttonPower();
                    if (this.showRadio) this.escapeRadio(true);
                    break;
                case 'setUiPositions':
                    let positions = event.data || {};
                    if (typeof positions !== 'object' || Array.isArray(positions)) positions = {};
                    this.positions = positions;
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
                case 'toggle_ai':
                    this.postRadioFrame({
                        type: 'toggle_ai',
                    });
                    break;
                case 'broadcastLocation':
                    this.postRadioFrame({
                        type: 'broadcast_location',
                        ...event.loc,
                    })
                    break;
                case 'update_scan_xmit_channels':
                    this.postRadioFrame({
                        type: 'update_scan_xmit_channels',
                        xmitToAdd: event.xmitToAdd,
                        xmitToRemove: event.xmitToRemove,
                        scanToAdd: event.scanToAdd,
                        scanToRemove: event.scanToRemove,
                    });
                    break;
            }
        },

        postRadioFrame(data) {
            getRadioFrameEl('radio')?.contentWindow.postMessage(data, '*');
        },
        setPttState(state) {
            const active = state === true;
            if (active) {
                if (this.pttActive || !this.radioPower) return;
                this.pttActive = true;
            } else {
                // Releases are intentionally repeated so a missed message cannot leave PTT active.
                this.pttActive = false;
            }
            this.postRadioFrame({ type: 'ptt', state: active });
        },
        updateRadioScreenStyle() {
            this.postRadioFrame({ type: 'screen_style', style: this.activeRadioScreenStyle });
        },
        onRadioFrameEvent(event) {
            switch (event.type) {
                case "radio_connected":
                    console.log('radio connected');
                    this.$store.commit('setConnected', { connected: true, identity: event.identity });
                    this.$store.commit('setRadioConfig', event.config);
                    this.postRadioFrame({ type: 'ptt', state: this.pttActive && this.radioPower });
                    this.publishStreamDeckSnapshot();
                    this.onStandaloneConnected();
                    this.updateRadioScreenStyle();
                    break;
                case "radio_disconnected":
                    this.pttActive = false;
                    this.$store.commit('setConnected', { connected: false });
                    this.publishStreamDeckSnapshot(this.getStreamDeckDefaultSnapshot());
                    break;
                case "pending_approval":
                    this.postClient({ type: 'radioNeedsAuth', accId: event.accId });
                    break;
                case "display_error":
                    this.notifyPlayer(`Radio Error: ${event.error}`, "~r~");
                    break;
                case "guest_login_request":
                    this.postClient({}, '/create-guest-token').then(res => {
                        this.postRadioFrame({ type: 'guest_login_response', ...res })
                    });
                    break;
                case 'config_updated':
                    this.$store.commit('setRadioConfig', event.config);
                    this.updateGamestate();
                    this.publishStreamDeckSnapshot();
                    break;
                case 'state_updated':
                    // include the identity in the state (used for audio ducking)
                    const state = {...event.state, identity: this.$store.state.identity};
                    this.$store.commit('setRadioState', state);
                    this.postClient({ type: 'stateUpdated', state });
                    this.publishStreamDeckSnapshot();
                    break;
                case 'mic_status':
                    this.$store.commit('setRadioTalking', event.micOpen);
                    this.postClient({ type: 'talking', talking: event.micOpen });
                    this.publishStreamDeckSnapshot();
                    break;
                case 'streamdeck_snapshot':
                    if (event.snapshot) this.publishStreamDeckSnapshot(event.snapshot);
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
                case 'route_to_postal':
                    this.postClient({
                        type: 'routeToPostal',
                        postal: event.postal
                    });
                    break;
                case 'route_to_coordinates':
                    this.postClient({
                        type: 'routeToCoordinates',
                        x: event.x,
                        y: event.y,
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
                    this.requestScannerProfilePerms();
                    break;
            }
        },
        postEmergencyCallFrame(data) {
            getRadioFrameEl('911')?.contentWindow.postMessage(data, '*');
        },
        syncEmergencyCallFrameStatus() {
            if (this.emergencyCall.status === 'closed') return;
            const showMicTroubleshooting = !!this.emergencyCall.showMicTroubleshooting;
            this.postEmergencyCallFrame({
                type: 'set_emergency_call_status',
                status: this.emergencyCall.status,
                showMicTroubleshooting,
                showMicSelector: showMicTroubleshooting,
                showMicLevelMeter: showMicTroubleshooting,
            });
        },
        closeEmergencyCallMicTroubleshooting() {
            if (!this.emergencyCall.showMicTroubleshooting) return;
            this.emergencyCall.showMicTroubleshooting = false;
            this.postClient({ type: 'emergencyCallMicTroubleshooting', active: false });
            this.syncEmergencyCallFrameStatus();
        },
        clearEmergencyCallMicWarning() {
            this.postClient({ type: 'emergencyCallMicWarning', active: false });
        },
        onEmergencyCallFrameEvent(event) {
            switch (event.type) {
                case 'radio_connected':
                    this.emergencyCall.state = event.state;
                    this.postClient({ type: 'stateUpdatedEmergencyCall', state: event.state });
                    this.syncEmergencyCallFrameStatus();
                    break;
                case "radio_disconnected":
                    // we were kicked on the radio, so end the call and destroy the frame
                    this.clearEmergencyCallMicWarning();
                    this.closeEmergencyCallMicTroubleshooting();
                    this.emergencyCall.status = 'closed';
                    break;
                case "call_status":
                    this.emergencyCall.status = event.newStatus;
                    break;
                case "call_peers":
                    this.emergencyCall.peers = event.peers;
                    break;
                case "redial_request":
                    this.postClient({ type: 'emergencyCallRedial' });
                    break;
                case "emergency_call_mic_warning":
                    console.log('received emergency_call_mic_warning', event);
                    this.postClient({
                        type: 'emergencyCallMicWarning',
                        active: !!event.active,
                        reason: event.reason,
                        deviceId: event.deviceId,
                        deviceLabel: event.deviceLabel,
                    });
                    break;
                case "display_error":
                    this.notifyPlayer(`Emergency Call Error: ${event.error}`, "~r~");
                    this.clearEmergencyCallMicWarning();
                    this.closeEmergencyCallMicTroubleshooting();
                    this.emergencyCall.status = 'closed'; // all errors are fatal
                    break;
            }
        },

        onKeyPressed(e, type) {
            if (type === 'keyup' && e.code === 'Escape') {
                if (this.dragMode)
                    this.dragMode = false;
                else
                    this.escapeRadio(false);
            } else if (type === 'keydown' && this.debug.enabled) {
                const dirs = {
                    'ArrowUp': 'up',
                    'ArrowDown': 'down',
                    'ArrowLeft': 'left',
                    'ArrowRight': 'right'
                };
                const dir = dirs[e.code];
                if (!dir) { /* pass */ }
                else if (!e.ctrlKey)
                    this.debugMoveFrameComponent(dir);
                else
                    this.debugResizeFrameComponent(dir);
            }

            const matchesPtt = e.code === this.pttKeyName || (this.pttKeyName?.startsWith('SpecialKey.') && e.code === this.pttKeyName.split('.')[1]);
            if (matchesPtt && !e.repeat) {
                if (e.preventDefault) e.preventDefault();
                this.setPttState(type === 'keydown');
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
            if (this.emergencyCall.showMicTroubleshooting) {
                this.closeEmergencyCallMicTroubleshooting();
                return;
            }

            this.postClient({ type: 'escape' });
            if (hide || this.escapeMode !== 'keep') this.showRadio = false;
            if (hide && this.debug.skinMenuExpanded) this.debug.skinMenuExpanded = false;
            if (this.scannerMenu.open) {
                this.scannerMenu.open = false;
                this.postClient({ type: 'saveScanner', id: this.scannerMenu.id }, 'scanners');
                return;
            }

            // notify player on how to hide radio if this is the first time
            const LS_KEY = 'hide_portable_hint_seen';
            if (hide || this.escapeMode !== 'keep' || localStorage.getItem(LS_KEY)) return;
            this.notifyPlayer('HINT: Use /radio hide or press the purple button to hide the radio', "~g~");
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

        notifyPlayer(message, colorCode) {
            this.postClient({ type: "notify", message: message, colorCode: colorCode });
        },
        updateGamestate() {
            const communityUserId = this.$store.state.cadCommunityUserId ?? null;
            this.postRadioFrame({
                type: "set_gamestate",
                state: {
                    tower_quality: this.towerQuality,
                    is_jammed: this.isJammed,
                    jammer_strength: this.jammerStrength,
                    communityUserId,
                },
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
        buttonVolUp() {
            this.postRadioFrame({ type: 'notch_vol_up' });
        },
        buttonVolDown() {
            this.postRadioFrame({ type: 'notch_vol_down' });
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
                this.notifyPlayer("Radio: Panic Pressed!", "~r~");
            else
                this.notifyPlayer('Radio: Stopped Panicking', "~r~");
            this.postRadioFrame({ type: 'set_panicking', panicking: !this.isPanicking });
        },
        changeNextPrevMode() {
            this.nextPrevMode = this.nextPrevMode === 'preset' ? 'group' : 'preset';
            if (this.nextPrevMode === 'preset')
                this.notifyPlayer(`Radio: Now selecting channels`, "~y~");
            else
                this.notifyPlayer(`Radio: Now selecting groups`, "~y~");
        },
        buttonPrev(e) {
            if (!this.$store.state.connected)
                this.notifyPlayer("Radio: Not Connected", "~r~")
            else if (e?.button === 2) {
                this.changeNextPrevMode();
            } else if (this.nextPrevMode === 'preset') {
                this.notifyPlayer("Radio: Previous channel", "~y~");
                this.prevPreset();
            } else {
                this.notifyPlayer("Radio: Previous group", "~y~");
                this.prevGroup();
            }
        },
        buttonNext(e) {
            if (!this.$store.state.connected)
                this.notifyPlayer("Radio: Not Connected", "~r~")
            else if (e?.button === 2) {
                this.changeNextPrevMode();
            } else if (this.nextPrevMode === 'preset') {
                this.notifyPlayer("Radio: Next channel", "~y~");
                this.nextPreset();
            } else {
                this.notifyPlayer("Radio: Next group", "~y~");
                this.nextGroup();
            }
        },
        buttonPower() {
            this.radioPower = !this.radioPower;
            this.postClient({
                type: 'power',
                power: this.radioPower
            });
            this.notifyPlayer(
                "Radio: " + (this.radioPower ? "On" : "Off"),
                this.radioPower ? "~g~" : "~r~"
            );

            if (this.radioPower) return;
            this.setPttState(false);
            // we need to remove the frame to "disconnect" from the radio
            // normally the iframe persists because it is only hidden, not disconnected
            this.$nextTick(() => {
                removeRadioFrame('radio');
            });
        },
        scannerPower() {
            this.scannerMenu.state = {
                powered: !this.scannerMenu.state?.powered,
                channelId: this.$store.getters.chatterDefaultProfileId
            };
            this.postClient({ type: 'setScanner', id: this.scannerMenu.id, state: this.scannerMenu.state }, 'scanners');
        },
        scannerAdvChannel(offset) {
            if (!this.scannerMenu.state) return;
            const profiles = this.$store.getters.chatterProfilesSorted.filter(x =>
                x.visibility === 'public' || this.scannerMenu.allowedProfileIds.includes(x.id)
            );
            const chId = this.scannerMenu.state.channelId || this.$store.getters.chatterDefaultProfileId;
            const idx = profiles.findIndex(x => x.id === chId) || 0;

            const nextIdx = (idx + offset + profiles.length) % profiles.length;
            this.$set(this.scannerMenu.state, 'channelId', profiles[nextIdx].id);
            this.postClient({ type: 'setScanner', id: this.scannerMenu.id, state: this.scannerMenu.state }, 'scanners');
        },
        async setEmergencyCall(newStatus, info) {
            if (typeof newStatus === 'boolean')
                newStatus = newStatus ? 'open' : 'idle';
            else if (newStatus === 'toggle')
                newStatus = this.emergencyCall.status === 'open' ? 'idle' : 'open';

            if (this.emergencyCall.status === 'closed' && newStatus !== 'closed') {
                // we're opening a call, create a guest (emergency call) token before actually connecting
                try {
                    const { guestToken } = await this.postClient({}, '/create-emergency-call-token');
                    if (guestToken) this.emergencyCall.token = guestToken;
                    else throw new Error('response OK but guestToken is invalid');
                } catch (err) {
                    this.notifyPlayer('Failed to start emergency call (Could not create token)', "~r~");
                    newStatus = 'closed';
                }
            }
            if (info?.displayName) this.emergencyCall.name = info.displayName;
            if (info?.cmd || info?.callCommand) this.emergencyCall.cmd = info.cmd || info.callCommand;
            if (info?.showHelpText != null) this.emergencyCall.showHelpText = info.showHelpText;
            if (info?.showMicTroubleshooting != null) this.emergencyCall.showMicTroubleshooting = info.showMicTroubleshooting;
            this.emergencyCall.status = newStatus;

            if (newStatus === 'closed') {
                // reset the emergency call state
                this.emergencyCall.peers = [];
                this.emergencyCall.state = null;
                this.emergencyCall.token = '';
                this.emergencyCall.showMicTroubleshooting = false;
                this.clearEmergencyCallMicWarning();
                this.postClient({ type: 'emergencyCallMicTroubleshooting', active: false });
            } else {
                // update the emergency call frame with the new state
                this.syncEmergencyCallFrameStatus();
            }
        },
        loop20() {
            if (this.emergencyCall.status === 'open') {
                const state = this.emergencyCall.state;
                if (state) this.postClient({ type: 'stateUpdatedEmergencyCall', state });
            } else if (this.radioPower) {
                // keep pushing stateUpdated every 20s
                // NOTE: chatter won't work without this (the server clears stale data after 30s of no update)
                const state = this.$store.state.radioState;
                if (state) this.postClient({ type: 'stateUpdated', state });
            }
        },
        requestScannerProfilePerms() {
            const profiles = this.$store.state.chatterConfig?.profiles || [];
            this.postClient({
                type: 'requestProfilePerms',
                profiles: profiles.map(x => ({
                    id: x.id,
                    displayName: x.displayName,
                })),
            }, 'scanners');
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

.emergency-call-frame-shell {
    position: fixed;
    top: 50%;
    left: 50%;
    width: 30vw;
    height: 20vh;
    transform: translate(-50%, -50%);
}
.emergency-call-frame-shell iframe {
    transform: scale(1.5);
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
