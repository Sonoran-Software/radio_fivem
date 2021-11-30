import Vue from 'vue';
import Vuex from 'vuex';

Vue.use(Vuex);

export default new Vuex.Store({
    state: {
        currFreq: {
            name: "Not Connected",
            recv: [155,195],
            xmit: [155,195]
        },
        gamestate: {
            position: [],
            radio_powered: false,
            tower_quality: 1
        },
        call: {
            code: "",
            title: "",
            location: "",
            description: ""
        },
        connColor: 'gray',
        presets: [],
        scanned: [],
        scanning: false,
        statusText: "Disconnected",
        subLevel: null,
        radios: []
    },
    getters: {},
    mutations: {},
    actions: {}
})