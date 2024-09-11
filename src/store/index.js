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
        radioConfig: null,
        radioState: null,
        gamestate: {
            position: [],
            radio_powered: false,
            tower_quality: 1
        },
        unitStatus: -1,
        call: {
            code: "",
            title: "",
            location: "",
            description: ""
        },
    },
    // TODO: getter for frequency label & sub level
    getters: {
        sublvl(state) {
            return state.radioConfig.subscription ?? 0;
        },
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
            else if (state.unitStatus >= 0)
                return "green";
            else
                return "lightblue";
        },
        freqRecv(state) {
            return state.radioState?.freqRecv;
        },
        freqXmit(state) {
            return state.radioState?.freqXmit;
        },
        channelProfile(state, getters) {
            if (!state.radioConfig) return null;

            let find = null;
            for (const prof of state.radioConfig.profiles) {
                // check if the receive frequencies of the profile match the current receive frequency
                if (!Array.isArray(getters.freqRecv) || getters.freqRecv[0] !== prof.recvFreqMajor || getters.freqRecv[1] !== prof.recvFreqMinor) continue;

                if (!prof.xmitFreqMajor) find = prof; // this profile doesn't have a transmit frequency, so it's the best match
                else if (Array.isArray(getters.freqXmit) && getters.freqXmit[0] === prof.xmitFreqMajor && getters.freqXmit[1] === prof.xmitFreqMinor) return prof;
            }
            return find;
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
                state.radioConfig = null;
                state.radioState = null;
                state.unitStatus = -1;
            }
        },
        setRadioConfig(state, radioConfig) {
            state.radioConfig = radioConfig;
        },
        setRadioState(state, radioState) {
            state.radioState = radioState;
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
    },
    actions: {}
})
