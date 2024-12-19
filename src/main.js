import "core-js/stable";
import "regenerator-runtime/runtime";
import Vue from "vue";
import App from "./App.vue";
import store from "./store";

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

const xsoundFrame = document.createElement('iframe');
xsoundFrame.src = `https://cfx-nui-${GetParentResourceName()}/lua/xsound/html/index.html`;
xsoundFrame.style.position = 'absolute';
xsoundFrame.style.top = '0px';
xsoundFrame.style.left = '0px';
xsoundFrame.style.right = '0px';
xsoundFrame.style.bottom = '0px';
xsoundFrame.style.width = '1px';
xsoundFrame.style.height = '1px';
xsoundFrame.style.border = '0px';
xsoundFrame.style.zIndex = '-1';
document.body.appendChild(xsoundFrame);

window.addEventListener('message', (ev) => {
  if (ev.data.miniradio) {
    ev.stopImmediatePropagation();
    miniradioFrame.contentWindow.postMessage(ev.data, '*');
    } else if (ev.data.xsound) {
    ev.stopImmediatePropagation();
    xsoundFrame.contentWindow.postMessage(ev.data, '*');
  }
});

// initialize the root element and vue instance
const el = document.createElement("div");
el.id = "root";
document.body.appendChild(el);

new Vue({
  el,
  store,
  render: (h) => h(App),
});
