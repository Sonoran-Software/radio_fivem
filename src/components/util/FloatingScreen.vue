<template>
    <div ref="guide" class="guide"></div>
</template>

<script>
export let frameEl;
let refs = 0;

/**
 * @param {DOMRect} bounds
 */
function push(el, svId) {
    refs++;

    // create frame if not exists
    const src = `https://radiov2.dev.sonoransoftware.com/view/${svId}`;
    if (!frameEl) {
        frameEl = document.createElement('iframe');
        frameEl.src = src;
        frameEl.allow = 'microphone';
        frameEl.id = 'standalone-screen';
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
        serverId: { type: Number, required: true },
    },
    emits: ['msg'],
    data: () => ({
        ro: null,
    }),
    mounted() {
        push(this.$refs.guide, this.serverId);

        this.ro = new ResizeObserver(() => this.flush());
        this.ro.observe(this.$refs.guide);
        window.addEventListener('message', this.onMessage);
    },
    beforeDestroy() {
        this.ro.disconnect();
        this.ro = null;
        window.removeEventListener('message', this.onMessage);
        pop();
    },
    watch: {
        serverId() {
            this.flush();
        },
    },
    methods: {
        flush() {
            pop();
            push(this.$refs.guide, this.serverId);
        },
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
