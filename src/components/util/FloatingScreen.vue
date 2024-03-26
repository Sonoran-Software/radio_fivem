<template>
    <div ref="guide" class="guide"></div>
</template>

<script>
let frame, refs = 0;

/**
 * @param {DOMRect} bounds
 */
function push(el, svId) {
    refs++;

    // create frame if not exists
    const src = `http://localhost:8080/view/${svId}`;
    if (!frame) {
        frame = document.createElement('iframe');
        frame.src = src;
        frame.allow = 'microphone';
        frame.id = 'standalone-screen';
        document.body.appendChild(frame);
    }
    if (frame.src !== src)
        frame.src = src;

    // scale iframe based on guide font size
    const elStyles = window.getComputedStyle(el);
    const bodyStyles = window.getComputedStyle(document.body);
    const scale = parseFloat(elStyles.fontSize) / parseFloat(bodyStyles.fontSize);
    frame.style.transform = `scale(${scale})`;

    // line up frame to guide
    const rect = el.getBoundingClientRect();
    frame.style.top = `${rect.top}px`;
    frame.style.left = `${rect.left}px`;
    frame.style.width = `${rect.width / scale}px`;
    frame.style.height = `${rect.height / scale}px`;
    frame.style.zIndex = elStyles.zIndex + 1;
    frame.style.visibility = 'visible';
}
function pop() {
    refs--;
    if (refs !== 0) return;

    frame.style.visibility = 'hidden';
}

export default {
    props: {
        serverId: { type: Number, required: true },
    },
    data: () => ({
        ro: null,
    }),
    mounted() {
        push(this.$refs.guide, this.serverId);

        this.ro = new ResizeObserver(() => this.flush());
        this.ro.observe(this.$refs.guide);
    },
    beforeDestroy() {
        this.ro.disconnect();
        this.ro = null;
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
