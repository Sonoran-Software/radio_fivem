import "core-js/stable";
import "regenerator-runtime/runtime";
import Vue from "vue";
import App from "./App.vue";
import store from "./store";

const innerFrames = {};

function hideManagedFrame(iframe) {
  iframe.style.pointerEvents = 'none';
  iframe.style.clipPath = 'inset(100%)';
  iframe.style.clip = 'rect(0px, 0px, 0px, 0px)';
}

function showManagedFrame(iframe, bounds) {
  if (!bounds) {
    hideManagedFrame(iframe);
    return;
  }

  const top = Math.max(0, bounds.top ?? 0);
  const left = Math.max(0, bounds.left ?? 0);
  const width = Math.max(0, bounds.width ?? 0);
  const height = Math.max(0, bounds.height ?? 0);
  const right = Math.max(0, window.innerWidth - (left + width));
  const bottom = Math.max(0, window.innerHeight - (top + height));

  iframe.style.pointerEvents = 'auto';
  iframe.style.clipPath = `inset(${top}px ${right}px ${bottom}px ${left}px)`;
  iframe.style.clip = `rect(${top}px, ${left + width}px, ${top + height}px, ${left}px)`;
}

window.addEventListener('message', (ev) => {
  const data = ev.data;
  if (!data || typeof data !== 'object' || !data.sonoranradioFrameControl)
    return;

  const iframe = innerFrames[data.frame];
  if (!iframe || ev.source !== iframe.contentWindow)
    return;

  ev.stopImmediatePropagation();
  if (!data.visible)
    return void hideManagedFrame(iframe);

  showManagedFrame(iframe, data.bounds);
});

/**
 * @param {string} src
 * @param {{
 *   key?: string,
 *   messageForwardKey?: string,
 *   zIndex?: string,
 *   managed?: boolean,
 *   pointerEvents?: string,
 *   tabIndex?: string,
 * }} [options]
 * @returns {HTMLIFrameElement}
 */
function addInnerFrame(src, options = {}) {
  const {
    key,
    messageForwardKey,
    zIndex = '-1',
    managed = false,
    pointerEvents = 'auto',
    tabIndex,
  } = options;
  const iframe = document.createElement('iframe');
  iframe.src = src;
  iframe.allow = 'microphone *';
  if (tabIndex !== undefined)
    iframe.tabIndex = Number(tabIndex);
  iframe.style.position = 'absolute';
  iframe.style.top = '0px';
  iframe.style.left = '0px';
  iframe.style.right = '0px';
  iframe.style.bottom = '0px';
  iframe.style.width = '100%';
  iframe.style.height = '100%';
  iframe.style.border = '0px';
  iframe.style.zIndex = zIndex;
  iframe.style.pointerEvents = pointerEvents;
  document.body.appendChild(iframe);

  if (key)
    innerFrames[key] = iframe;
  if (managed)
    hideManagedFrame(iframe);

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

addInnerFrame(`https://cfx-nui-${GetParentResourceName()}/miniradio/miniradio.html`, {
  key: 'miniradio',
  messageForwardKey: 'miniradio',
  zIndex: '-1',
  managed: true,
});
addInnerFrame(`https://cfx-nui-${GetParentResourceName()}/lua/xsound/html/index.html`, {
  key: 'xsound',
  messageForwardKey: 'xsound',
  zIndex: '-3',
  pointerEvents: 'none',
  tabIndex: '-1',
});
addInnerFrame(`https://cfx-nui-${GetParentResourceName()}/tablet/tablet.html`, {
  key: 'tablet',
  messageForwardKey: 'tablet',
  zIndex: '-2',
  managed: true,
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
