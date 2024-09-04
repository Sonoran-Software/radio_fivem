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

const miniradioFrame = document.createElement('iframe');
miniradioFrame.src = `https://cfx-nui-${GetParentResourceName()}/miniradio/miniradio.html`;
miniradioFrame.style.position = 'absolute';
miniradioFrame.style.top = '0px';
miniradioFrame.style.left = '0px';
miniradioFrame.style.right = '0px';
miniradioFrame.style.bottom = '0px';
miniradioFrame.style.width = '100%';
miniradioFrame.style.height = '100%';
miniradioFrame.style.border = '0px';
miniradioFrame.style.zIndex = '-1';
document.body.appendChild(miniradioFrame);
