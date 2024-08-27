<template>
    <div ref="guide" class="guide"></div>
</template>

<script>
/** @type {HTMLIFrameElement | null} */
export let frameEl = null;
let refs = 0;

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
    // frameEl.style.visibility = 'visible';
}
function pop() {
    if (--refs !== 0) return;
    frameEl.style.opacity = '0%';
    // frameEl.style.visibility = 'hidden';
}

export default {
    props: {
        serverId: { type: [Number, String], required: true },
        url: { type: String },
        chatter: { type: Boolean },
    },
    emits: ['load'],
    data: () => ({
        ro: null,
    }),
    mounted() {
        push(!this.chatter ? this.$refs.guide : null, this.frameSrc);

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
    computed: {
        frameSrc() {
            const url = this.url || 'https://sonoranradio.com';
            const page = this.chatter ? 'chatter-engine' : 'view';
            // EXAMPLES:
            // https://sonoranradio.com/view/ABC123?fivem=true
            // https://radio.dev.sonoransoftware.com/chatter-engine/ABC123?fivem=true
            return `${url}/${page}/${this.serverId}?fivem=true`;
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
            }
            push(!this.chatter ? this.$refs.guide : null, this.frameSrc);
        }
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
