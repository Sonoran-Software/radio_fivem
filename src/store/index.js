import Vue from 'vue';
import Vuex from 'vuex';

Vue.use(Vuex);

const freqToString = (freq) => {
    if (freq[0] === 'xxx') return 'N/A';
    return `${freq[0]}.${freq[1].toString().padStart(3, '0')}`;
};

export default new Vuex.Store({
    state: {
        connected: false,
        sublvl: 0,
        currFreq: {
            recv: ['xxx','xxx'],
            xmit: ['xxx','xxx']
        },
        gamestate: {
            position: [],
            radio_powered: false,
            tower_quality: 1
        },
        talkers: [],
        unitStatus: -1,
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
        presets: [],
        scanned: [],
        scanning: false,
        radios: [],
        inVehicle: false
    },
    // TODO: getter for frequency label & sub level
    getters: {
        statusText(state) {
            const unitStatusNames = [
                "Unavailable",
                "Busy",
                "Available",
                "En Route",
                "On Scene",
                "Clocked Out"
            ];
            if (state.unitStatus < 0)
                return state.connected ? 'Connected' : 'Disconnected';
            else
                return unitStatusNames[state.unitStatus];
        },
        connColor(state) {
            if (!state.connected)
                return "gray";
            else if (state.talkers.find(t => t.isSelf))
                return "red";
            else if (state.talkers.length > 0)
                return "yellow";
            else if (state.unitStatus >= 0)
                return "green";
            else
                return "lightblue";
        },
        freqName(state) {
            const {recv, xmit} = state.currFreq;
            for (const p of state.presets) {
                const {freq_recv, freq_xmit} = p;
                if (freq_recv[0] === recv[0] &&
                    freq_recv[1] === recv[1] &&
                    freq_xmit[0] === xmit[0] &&
                    freq_xmit[1] === xmit[1]) {
                    return p.display_name || null;
                }
            }
            return null;
        },
        isInVehicle(state) {
            return state.inVehicle;
        },
        recvFreqStr(state) {
            return freqToString(state.currFreq.recv);
        },
        xmitFreqStr(state) {
            return freqToString(state.currFreq.xmit);
        },
    },
    mutations: {
        setConnected(state, connected) {
            state.connected = connected;
            if (!connected) {
                state.sublvl = 0;
                state.currFreq.recv = ['xxx', 'xxx'];
                state.currFreq.xmit = ['xxx', 'xxx'];
                state.unitStatus = -1;
                state.presets = [];
                state.scanned = [];
                state.scanning = false;
            }
        },
        setConfig(state, config) {
            state.sublvl = config.sublvl;
            state.presets = config.profiles.map(x => ({
                display_name: x.display_name,
                freq_recv: x.freq_recv,
                freq_xmit: x.freq_xmit,
            }));
        },
        setFreqs(state, { recv, xmit }) {
            state.currFreq.recv = recv;
            state.currFreq.xmit = xmit;
        },
        setScanList(state, list) {
            state.scanned = [...list];
        },
        setScanState(state, status) {
            state.scanning = status;
        },
        addXmitState(state, { xmit_type, can_hear, client }) {
            if (xmit_type.includes('talk_permit') && can_hear) {
                state.talkers.push({
                    id: client.id,
                    nickname: client.nickname,
                    isSelf: client.self,
                });
            } else if (xmit_type.includes('squelch')) {
                // remove from talkers by client id
                state.talkers = state.talkers.filter(talker => talker.id !== client.id);
            }
        },
        setCall(state, { code, title, postal, address, description }) {
            try {
                state.call.code = code;
                state.call.title = title;
                state.call.location = (postal != "" ? postal + " " + address : address);
                state.call.description = description;
            } catch (e) {
                console.error("Failed to update call information");
                console.error(e);
            }
        },
        setUnitStatus(state, status) {
            state.unitStatus = status;
        },
        setActiveRadios(state, radios) {
            state.radios = radios;
        },
        setInVehicle(state, isInVehicle) {
            state.inVehicle = isInVehicle;
        }
    },
    actions: {}
})
