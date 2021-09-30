import Vue from "vue";
import App from "./App.vue";
import store from './store';

const el = document.createElement('div');
el.id = 'root';
document.body.appendChild(el);

new Vue({
    el,
    store,
    render: (h) => h(App),
});
