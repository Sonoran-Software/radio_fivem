<template>
    <div ref="guide" class="guide"></div>
</template>

<script>
/** @type {HTMLIFrameElement | null} */
export let frameEl = null;
let refs = 0;
let cacheBust = Date.now();

/**
 * @param {HTMLElement?} el
 * @param {string} src
 */
function push(el, src) {
    refs++;

    // create frame if not exists
    if (!frameEl) {
        frameEl = document.createElement('iframe');
        frameEl.src = src;
        frameEl.allow = 'microphone';
        frameEl.id = 'standalone-frame';
        frameEl.name = 'sonoranradio-standalone-screen';
        document.body.appendChild(frameEl);
    }
    if (frameEl.src !== src)
        frameEl.src = src;

    frameEl.style.pointerEvents = 'auto';
    // the caller wants the frame to exist, but not be visible
    if (!el) return;

    // scale iframe based on guide font size
    const elStyles = window.getComputedStyle(el);
    const bodyStyles = window.getComputedStyle(document.body);
    const scale = parseFloat(elStyles.fontSize) / parseFloat(bodyStyles.fontSize);
    frameEl.style.transform = `scale(${scale})`;

    // line up frame to guide
    const rect = el.getBoundingClientRect();
    frameEl.style.top = `${rect.top}px`;
    frameEl.style.left = `${rect.left}px`;
    frameEl.style.width = `${rect.width / scale}px`;
    frameEl.style.height = `${rect.height / scale}px`;
    frameEl.style.zIndex = elStyles.zIndex + 1;
    frameEl.style.opacity = '100%';
}
function pop() {
    if (--refs !== 0) return;
    frameEl.style.opacity = '0%';
    frameEl.style.pointerEvents = 'none';
}

export default {
    props: {
        serverId: { type: [Number, String], required: true },
        url: { type: String, default: 'https://sonoranradio.com' },
        feature: { type: String, default: 'radio' },
        displayName: { type: String },
    },
    emits: ['load'],
    data: () => ({
        interval: null,
        lastGuide: null,
        cacheBust,
    }),
    mounted() {
        push(this.shouldBeVisible ? this.$refs.guide : null, this.frameSrc);
        frameEl.addEventListener('load', this.onLoad);
        this.interval = setInterval(() => this.intervalRefresh(), 50);
        this.lastGuide = this.$refs['guide'].getBoundingClientRect();
    },
    beforeDestroy() {
        clearInterval(this.interval);
        frameEl.removeEventListener('load', this.onLoad);
        pop();
    },
    computed: {
        shouldBeVisible() {
            return this.feature === 'radio';
        },
        frameSrc() {
            const pages = {
                radio: 'view',
                chatter: 'chatter-engine',
                ['911']: 'emergency-call',
            };
            const page = pages[this.feature];

            const query = new URLSearchParams();
            if (this.displayName) query.append('displayName', this.displayName);
            query.append('autoconnect', 'true');
            query.append('fivem', 'true');
            query.append('cacheBust', this.cacheBust);
            return `${this.url}/${page}/${this.serverId}?${query.toString()}`;
        }
    },
    watch: {
        frameSrc() {
            this.flush();
        },
    },
    methods: {
        onLoad() {
            this.$emit('load');
        },
        flush(force) {
            pop();
            if (force) {
                frameEl.remove();
                frameEl = null;

                const setTo = Date.now();
                this.cacheBust = cacheBust = setTo;
            }
            push(this.shouldBeVisible ? this.$refs.guide : null, this.frameSrc);
        },
        intervalRefresh() {
            if (!this.shouldBeVisible) return;
            const threshold = 0.5; // 0.5px
            const guide = this.$refs['guide'].getBoundingClientRect();

            // constantly check if the guide has moved
            const needsFlush = Math.abs(guide.top - this.lastGuide.top) > threshold
                || Math.abs(guide.left - this.lastGuide.left) > threshold
                || Math.abs(guide.width - this.lastGuide.width) > threshold
                || Math.abs(guide.height - this.lastGuide.height) > threshold;
            this.lastGuide = guide;
            // flush if moved
            if (needsFlush) this.flush();
        },
    },
};
</script>

<style>
#standalone-frame {
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
