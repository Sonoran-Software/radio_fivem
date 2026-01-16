import "core-js/stable";
import "regenerator-runtime/runtime";
import Vue from "vue";
import App from "./App.vue";
import store from "./store";

/**
 * @param {string} src 
 * @param {string | undefined} messageForwardKey
 * @returns {HTMLIFrameElement}
 */
function addInnerFrame(src, messageForwardKey) {
  const iframe = document.createElement('iframe');
  iframe.src = src;
  iframe.style.position = 'absolute';
  iframe.style.top = '0px';
  iframe.style.left = '0px';
  iframe.style.right = '0px';
  iframe.style.bottom = '0px';
  iframe.style.width = '100%';
  iframe.style.height = '100%';
  iframe.style.border = '0px';
  iframe.style.zIndex = '-1';
  document.body.appendChild(iframe);

  if (messageForwardKey) {
    window.addEventListener('message', (ev) => {
      if (ev.data && typeof ev.data === 'object' && ev.data[messageForwardKey]) {
        ev.stopImmediatePropagation();
        iframe.contentWindow.postMessage(ev.data, '*');
      }
    });
  }

  return iframe;
}

addInnerFrame(`https://cfx-nui-${GetParentResourceName()}/miniradio/miniradio.html`, 'miniradio');
addInnerFrame(`https://cfx-nui-${GetParentResourceName()}/lua/xsound/html/index.html`, 'xsound');
addInnerFrame(`https://cfx-nui-${GetParentResourceName()}/tablet/tablet.html`, 'tablet');

// initialize the root element and vue instance
const el = document.createElement("div");
el.id = "root";
document.body.appendChild(el);

new Vue({
  el,
  store,
  render: (h) => h(App),
});
