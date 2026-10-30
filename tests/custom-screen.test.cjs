// Run with: node --test tests/custom-screen.test.cjs
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { test } = require('node:test');
const { transformSync } = require('@babel/core');
const { parseComponent } = require('vue/compiler-sfc');
const Vue = require('vue');

const source = readFileSync(resolve(__dirname, '../src/App.vue'), 'utf8');
const { code } = transformSync(parseComponent(source).script.content, {
    babelrc: false,
    configFile: false,
    presets: [[require.resolve('@babel/preset-env'), { targets: { node: 'current' } }]],
});

function createRadio(t) {
    const messages = [];
    const componentModule = { exports: {} };
    // Load the real component script, replacing only its visual dependencies
    // and the browser's iframe boundary. Vue runs its computed values/watchers.
    new Function('require', 'module', 'exports', code)(
        (name) => name === './components/StandaloneFrame.vue' ? {
            getFrameEl: () => ({
                contentWindow: {
                    postMessage: (message) => messages.push(JSON.parse(JSON.stringify(message))),
                },
            }),
        } : {},
        componentModule,
        componentModule.exports,
    );
    const App = componentModule.exports.default;
    const app = new Vue({
        data: App.data,
        computed: App.computed,
        watch: App.watch,
        methods: {
            ...App.methods,
            postClient() {},
            publishStreamDeckSnapshot() {},
        },
        beforeCreate() {
            this.$store = {
                state: { radioState: null, radioConfig: {}, peersTalking: [], talking: false },
                commit() {},
            };
        },
    });
    app.showRadio = true;
    app.radioPower = true;
    t.after(() => app.$destroy());
    return {
        app,
        messages,
        lastScreen: () => messages.filter((message) => message.type === 'screen_style').at(-1),
    };
}

const screen = (brandText) => ({
    style: 'custom',
    custom: { version: 1, brandText, colors: { background: '#123456' } },
});
const skin = (screenConfig, extraFrames = []) => ({
    id: 'frame:7',
    frames: [{ type: 'portable', screen: screenConfig, controls: [] }, ...extraFrames],
});

test('selecting a custom frame sends its style and saved design to the radio', async (t) => {
    const { app, lastScreen } = createRadio(t);
    app.curSkin = skin({ style: 'modern' });
    await Vue.nextTick();
    app.curSkin = skin(screen('FIRE'));
    await Vue.nextTick();
    assert.deepEqual(lastScreen(), { type: 'screen_style', ...screen('FIRE') });
});

test('switching between custom frames sends the new design even when the style is unchanged', async (t) => {
    const { app, messages, lastScreen } = createRadio(t);
    app.curSkin = skin(screen('FIRE'));
    await Vue.nextTick();
    messages.length = 0;
    app.curSkin = { ...skin(screen('POLICE')), id: 'frame:8' };
    await Vue.nextTick();
    assert.deepEqual(lastScreen(), { type: 'screen_style', ...screen('POLICE') });
});

test('updates to the active custom design reach the persistent iframe', async (t) => {
    const { app, messages, lastScreen } = createRadio(t);
    app.curSkin = skin(screen('FIRE'));
    await Vue.nextTick();
    messages.length = 0;
    app.curSkin.frames[0].screen.custom.brandText = 'RESCUE';
    await Vue.nextTick();
    assert.deepEqual(lastScreen(), { type: 'screen_style', ...screen('RESCUE') });
});

test('vehicle and aircraft layouts use their own screens and restore the portable design', async (t) => {
    const { app, lastScreen } = createRadio(t);
    app.curSkin = skin(screen('PORTABLE'), [
        { type: 'vehicle', vehicleClasses: [18], screen: screen('VEHICLE'), controls: [] },
        { type: 'vehicle', vehicleClasses: [15, 16], screen: screen('AIRCRAFT'), controls: [] },
    ]);
    await Vue.nextTick();
    for (const [vehicleClass, brandText] of [[18, 'VEHICLE'], [15, 'AIRCRAFT'], [-1, 'PORTABLE']]) {
        app.inVehicleClass = vehicleClass;
        await Vue.nextTick();
        assert.deepEqual(lastScreen(), { type: 'screen_style', ...screen(brandText) });
    }
});

test('reopening a hidden radio and reconnecting resend the saved custom screen', async (t) => {
    const { app, messages, lastScreen } = createRadio(t);
    app.curSkin = skin(screen('FIRE'));
    await Vue.nextTick();
    app.showRadio = false;
    await Vue.nextTick();
    messages.length = 0;
    app.showRadio = true;
    await Vue.nextTick();
    assert.deepEqual(lastScreen(), { type: 'screen_style', ...screen('FIRE') });
    messages.length = 0;
    app.onRadioFrameEvent({ type: 'radio_connected', identity: 'test-user', config: {} });
    assert.deepEqual(lastScreen(), { type: 'screen_style', ...screen('FIRE') });
});

test('built-in frames clear the custom design and keep their selected style', async (t) => {
    const { app, lastScreen } = createRadio(t);
    app.curSkin = skin(screen('FIRE'));
    await Vue.nextTick();
    for (const style of ['text', 'modern', 'mobi', 'unknown']) {
        app.curSkin = skin({ style });
        await Vue.nextTick();
        assert.deepEqual(lastScreen(), {
            type: 'screen_style',
            style: style === 'unknown' ? 'modern' : style,
            custom: null,
        });
    }
});
