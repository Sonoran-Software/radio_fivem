<template>
    <div ref="guide" class="guide"></div>
</template>

<script>
let cacheBust = Date.now();

/** @type {Record<string, {el: HTMLIFrameElement, refs: number}>} */
const frames = {};

/**
 * @param {string} key
 * @param {HTMLElement?} el
 * @param {string} src
 * @returns {void}
 */
function push(key, el, src, expanded = false) {
    let frameData = frames[key];

    // create frame if not exists
    if (!frameData) {
        const frameEl = document.createElement('iframe');
        frameEl.src = src;
        frameEl.allow = 'microphone';
        frameEl.id = `sonoranradio-${key}-frame`;
        frameEl.name = 'sonoranradio-screen';
        frameEl.classList.add('sonoranradio-iframe');
        document.body.appendChild(frameEl);

        frames[key] = frameData = {el: frameEl, refs: 0};
    }

    frameData.refs++;

    const frameEl = frameData.el;
    if (frameEl.src !== src)
        frameEl.src = src;
    // the caller wants the frame to exist, but not be visible
    if (!el) {
        frameEl.style.opacity = '0%';
        frameEl.style.pointerEvents = 'none';
        frameEl.style.zIndex = '';
        return;
    }
    frameEl.style.pointerEvents = 'auto';

    // The ordinary radio viewport follows the skin's screen. Settings use the
    // entire radio body, matching the desktop overlay's available viewport.
    const boundsEl = expanded ? el.closest('.radio-frame') || el : el;
    const elStyles = window.getComputedStyle(el);
    const bodyStyles = window.getComputedStyle(document.body);
    const scale = expanded ? 1 : parseFloat(elStyles.fontSize) / parseFloat(bodyStyles.fontSize);
    frameEl.style.transform = expanded ? '' : `scale(${scale})`;
    frameEl.style.zIndex = expanded ? '1000' : '';

    // line up frame to guide
    const bodyRect = boundsEl.getBoundingClientRect();
    // A bottom-anchored radio can be taller than the game viewport. Keep the
    // settings header reachable while covering the visible part of its body.
    const left = expanded ? Math.max(0, Math.min(bodyRect.left, window.innerWidth)) : bodyRect.left;
    const top = expanded ? Math.max(0, Math.min(bodyRect.top, window.innerHeight)) : bodyRect.top;
    const right = expanded ? Math.max(left, Math.min(bodyRect.right, window.innerWidth)) : bodyRect.right;
    const bottom = expanded ? Math.max(top, Math.min(bodyRect.bottom, window.innerHeight)) : bodyRect.bottom;
    const rect = { left, top, width: right - left, height: bottom - top };
    frameEl.style.top = `${rect.top}px`;
    frameEl.style.left = `${rect.left}px`;
    frameEl.style.width = `${rect.width / scale}px`;
    frameEl.style.height = `${rect.height / scale}px`;
    frameEl.style.opacity = '100%';
}
/**
 * @param {string} key
 * @param {boolean} remove
 */
function pop(key, remove) {
    const frameData = frames[key];
    if (!frameData) return;

    if (remove) {
        delete frames[key];
        // allow the frame to unload before being removed
        frameData.el.contentWindow.location.replace('about:blank');
        setTimeout(() => frameData.el.remove(), 0);
    } else if (--frameData.refs <= 0) {
        frameData.el.style.opacity = '0%';
        frameData.el.style.pointerEvents = 'none';
    }
}

/**
 * @param {string} key
 * @returns {HTMLIFrameElement | undefined}
 */
export function getFrameEl(key) {
    return frames[key]?.el;
}
/**
 * @param {string} key
 */
export function removePersistentFrame(key) {
    const refs = frames[key]?.refs ?? 0;
    if (refs > 0) throw new Error('cannot remove persistent frame with references');
    pop(key, true);
}

export default {
    props: {
        serverId: { type: [Number, String], required: true },
        url: { type: String, default: 'https://sonoranradio.com' },
        feature: { type: String, default: 'radio' },
        query: { type: Object, default: () => ({}) },
        visible: { type: Boolean, default: false },
        iframePersistent: { type: Boolean, default: false },
        expanded: { type: Boolean, default: false },
    },
    data: () => ({
        interval: null,
        lastGuide: null,
        lastBody: null,
        lastViewport: null,
        cacheBust,
    }),
    mounted() {
        push(this.feature, this.shouldBeVisible ? this.$refs.guide : null, this.frameSrc, this.expanded);
        this.interval = setInterval(() => this.intervalRefresh(), 50);
        this.lastGuide = this.$refs['guide'].getBoundingClientRect();
        this.lastBody = this.$refs.guide.closest('.radio-frame')?.getBoundingClientRect();
        this.lastViewport = [window.innerWidth, window.innerHeight];
    },
    beforeDestroy() {
        clearInterval(this.interval);
        pop(this.feature, !this.iframePersistent);
    },
    computed: {
        shouldBeVisible() {
            return this.feature === 'radio' || this.visible;
        },
        frameSrc() {
            const pages = {
                radio: 'view',
                chatter: 'chatter-engine',
                ['911']: 'emergency-call',
            };
            const page = pages[this.feature];

            const query = new URLSearchParams();
            for (const [key, value] of Object.entries(this.query))
                if (value)
                    query.append(key, value);
            query.append('autoconnect', 'true');
            query.append('fivem', 'true');
            query.append('cacheBust', this.cacheBust);
            return `${this.url}/${page}/${this.serverId}?${query.toString()}`;
        }
    },
    watch: {
        frameSrc() {
            this.$emit('source-change');
            this.flush();
        },
        shouldBeVisible() {
            this.flush();
        },
        expanded() {
            this.flush();
        },
    },
    methods: {
        flush(force) {
            pop(this.feature, force);
            if (force) {
                const setTo = Date.now();
                this.cacheBust = cacheBust = setTo;
            }
            push(this.feature, this.shouldBeVisible ? this.$refs.guide : null, this.frameSrc, this.expanded);
        },
        intervalRefresh() {
            if (!this.shouldBeVisible) return;
            const threshold = 0.5; // 0.5px
            const guide = this.$refs['guide'].getBoundingClientRect();
            const body = this.expanded ? this.$refs.guide.closest('.radio-frame')?.getBoundingClientRect() : null;
            const viewport = [window.innerWidth, window.innerHeight];

            // constantly check if the guide has moved
            const needsFlush = Math.abs(guide.top - this.lastGuide.top) > threshold
                || Math.abs(guide.left - this.lastGuide.left) > threshold
                || Math.abs(guide.width - this.lastGuide.width) > threshold
                || Math.abs(guide.height - this.lastGuide.height) > threshold
                || (body && (!this.lastBody
                    || Math.abs(body.top - this.lastBody.top) > threshold
                    || Math.abs(body.left - this.lastBody.left) > threshold
                    || Math.abs(body.width - this.lastBody.width) > threshold
                    || Math.abs(body.height - this.lastBody.height) > threshold))
                || (this.expanded && (viewport[0] !== this.lastViewport[0]
                    || viewport[1] !== this.lastViewport[1]));
            this.lastGuide = guide;
            this.lastBody = body;
            this.lastViewport = viewport;
            // flush if moved
            if (needsFlush) this.flush();
        },
    },
};
</script>

<style>
iframe.sonoranradio-iframe {
    position: fixed;
    margin: 0;
    padding: 0;
    border: none;
    overflow: hidden;
    transform-origin: 0 0;
}
</style>

<style scoped>
.guide {
    height: 100%;
}
</style>
