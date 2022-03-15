import Vue from 'vue';
import Vuex from 'vuex';

Vue.use(Vuex);

export default new Vuex.Store({
    state: {
        sublvl: 0,
        currFreq: {
            name: "Disconnected",
            recv: ['xxx','xxx'],
            xmit: ['xxx','xxx']
        },
        gamestate: {
            position: [],
            radio_powered: false,
            tower_quality: 1
        },
        voicestate: {
            recv: false,
            xmit: false,
            talker: ""
        },
        call: {
            code: "",
            title: "",
            location: "",
            description: ""
        },
        conversations: [],
        recipient: {
            id: null,
            name: null
        },
        connColor: 'gray',
        connColorDefault: 'gray',
        presets: [],
        scanned: [],
        scanning: false,
        statusText: "Disconnected",
        subLevel: null,
        radios: []
    },
    getters: {
        presets(state) {
            return state.presets;
        },
        scanner(state) {
            return {list: state.scanned, status: state.scanning};
        }
    },
    mutations: {
        setConnected(state, connected) {
            state.statusText = connected ? "Connected" : "Disconnected";
            state.currFreq.name = state.statusText;
            state.connColor = connected ? "lightblue" : "gray";
            state.connColorDefault = connected ? "lightblue" : "gray";
            if (!connected) {
                state.sublvl = 0;
                state.currFreq.recv = ['xxx', 'xxx'];
                state.currFreq.xmit = ['xxx', 'xxx'];
                state.presets = [];
                state.scanned = [];
                state.scanning = false;
            }
        },
        setPresets(state, presets) {
            state.presets = presets;
        },
        setScanList(state, list) {
            state.scanned = list;
        }
    },
    actions: {}
})