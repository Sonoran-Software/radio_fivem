import Vue from "vue";
import App from "./App.vue";

const el = document.createElement('div');
el.id = 'root';
document.body.appendChild(el);

new Vue({
    el,
    render: (h) => h(App),
});
