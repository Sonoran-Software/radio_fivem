import Vue from 'vue';
import Vuex from 'vuex';

Vue.use(Vuex);

export default new Vuex.Store({
    state: {
        currFreq: {
            name: "empty",
            recv: [0,0],
            xmit: [0,0]
        },
        presets: [],
        scanned: [],
        statusText: ""
    },
    getters: {},
    mutations: {},
    actions: {}
})