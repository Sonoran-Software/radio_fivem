<template>
    <div ref="guide" class="guide"></div>
</template>

<script>
/** @type {HTMLIFrameElement | null} */
export let frameEl = null;
let refs = 0;
let cacheBust = Date.now();
/**
 * @param {HTMLElement} el
 * @param {number} svId
 * @param {string} url
 */
function push(el, svId, url) {
    refs++;

    // create frame if not exists
    url = url || 'https://sonoranradio.com'
    const src = `${url}/view/${svId}?fivem=true&cachebuster=${cacheBust}`;
    if (!frameEl) {
        frameEl = document.createElement('iframe');
        frameEl.src = src;
        frameEl.allow = 'microphone';
        frameEl.id = 'standalone-screen';
        frameEl.name = 'sonoranradio-standalone-screen';
        document.body.appendChild(frameEl);
    }
    if (frameEl.src !== src)
        frameEl.src = src;

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
    frameEl.style.visibility = 'visible';
}
function pop() {
    refs--;
    if (refs !== 0) return;

    frameEl.style.visibility = 'hidden';
}

export default {
    props: {
        serverId: { type: [Number, String], required: true },
        url: { type: String },
    },
    emits: ['load'],
    data: () => ({
        ro: null,
    }),
    mounted() {
        push(this.$refs.guide, this.serverId, this.url);

        frameEl.addEventListener('load', this.onLoad);
        this.ro = new ResizeObserver(() => this.flush());
        this.ro.observe(this.$refs.guide);
    },
    beforeDestroy() {
        this.ro.disconnect();
        this.ro = null;
        frameEl.removeEventListener('load', this.onLoad);
        pop();
    },
    watch: {
        serverId() {
            this.flush();
        },
        url() {
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
            }
            push(this.$refs.guide, this.serverId, this.url);
        }
    },
};
</script>

<style>
#standalone-screen {
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
