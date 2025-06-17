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
        identity: null,

        radioConfig: null,
        radioState: null,
        talking: false,
        peersTalking: [],

        chatterConfig: null,
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
        channelProfile(state) {
            const profiles = state.radioConfig?.profiles.filter(x =>
                state.radioState?.primaryChIds.includes(x.id)
            );
            return profiles[0];
        },
        freqRecv(_state, getters) {
            if (!getters.channelProfile) return null;
            return [getters.channelProfile.recvFreqMajor, getters.channelProfile.recvFreqMinor];
        },
        freqXmit(_state, getters) {
            if (!getters.channelProfile) return null;
            return [getters.channelProfile.xmitFreqMajor, getters.channelProfile.xmitFreqMinor];
        },
        recvFreqStr(_state, getters) {
            return getters.freqRecv && freqToString(getters.freqRecv);
        },
        xmitFreqStr(_state, getters) {
            return getters.freqXmit && freqToString(getters.freqXmit);
        },
        chatterProfilesSorted(state) {
            const profiles = state.chatterConfig?.profiles || [];
            return [...profiles].sort((a, b) => {
                const an = typeof a.orderIndex === 'number' ? a.orderIndex : Infinity;
                const bn = typeof b.orderIndex === 'number' ? b.orderIndex : Infinity;
                return an - bn;
            });
        },
        chatterDefaultProfileId(state) {
            if (typeof state.chatterConfig?.defaultProfileId === 'number')
                return state.chatterConfig.defaultProfileId;
            else if (state.chatterConfig?.profiles.length)
                return state.chatterConfig?.profiles[0].id;
            return 0; // either no channels exists, or the chatterConfig has not loaded yet
        },
    },
    mutations: {
        setConnected(state, {connected, identity}) {
            state.connected = connected;
            state.identity = identity;
            if (!connected) {
                state.radioConfig = null;
                state.radioState = null;
                state.talking = false;
                state.peersTalking = [];
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
        setChatterConfig(state, config) {
            state.chatterConfig = config;
        }
    },
    actions: {}
})
