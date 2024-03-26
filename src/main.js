import "core-js/stable";
import "regenerator-runtime/runtime";
import Vue from "vue";
import App from "./App.vue";
import store from "./store";

const el = document.createElement("div");
el.id = "root";
document.body.appendChild(el);

new Vue({
  el,
  store,
  render: (h) => h(App),
});

let screenPortalEl = null;
Vue.directive("standalone-portal", {
  inserted(el) {
    if (!screenPortalEl) {
      const frame = document.createElement("iframe");
      frame.src = "http://localhost:8080/view/6";
      frame.allow = "microphone";
      frame.id = "standalone-screen";

      screenPortalEl = document.createElement("div");
      screenPortalEl.appendChild(frame);
      screenPortalEl.id = "standalone-portal";
    }
    el.appendChild(screenPortalEl);
  },
  unbind(el) {
    document.body.appendChild(screenPortalEl);
  },
});
