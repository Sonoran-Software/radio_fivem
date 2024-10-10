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
        talking: false,
        peersTalking: [],
    },
    // TODO: getter for frequency label & sub level
    getters: {
        sublvl(state) {
            return state.radioConfig.subscription ?? 0;
        },
        statusText(state) {
            return state.connected ? 'Connected' : 'Disconnected';
        },
        connColor(state) {
            if (!state.connected)
                return "gray";
            else if (state.talking)
                return "orange";
            else if (state.peersTalking.length > 0)
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
        recvFreqStr(_state, getters) {
            return freqToString(getters.freqRecv);
        },
        xmitFreqStr(_state, getters) {
            return freqToString(getters.freqXmit);
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
        setRadioTalking(state, talking) {
            state.talking = talking;
        },
        setPeerTalkStatus(state, peer) {
            const idx = state.peersTalking.findIndex(p => p.identity === peer.identity);
            if (peer.micOpen && peer.canHear) {
                if (idx >= 0) state.peersTalking[idx] = peer; // update peer
                else state.peersTalking.push(peer);
            } else if (idx >= 0)
                state.peersTalking.splice(idx, 1);
        },
        setUnitStatus(state, status) {
            state.unitStatus = status;
        },
    },
    actions: {}
})
