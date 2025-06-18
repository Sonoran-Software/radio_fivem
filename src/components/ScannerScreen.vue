<template>
    <div class="scanner-screen backlight-green">
        <div class="ellipsis-2">
            <b>{{ channelName }}</b>
        </div>
    </div>
</template>

<script>
export default {
    props: {
        state: { type: Object, required: true }
    },
    computed: {
        channelName() {
            const chId = this.state.channelId || this.$store.getters.chatterDefaultProfileId;
            const prof = this.$store.getters.chatterProfilesSorted.find(x => x.id === chId);
            return prof?.displayName || 'unknown';
        }
    },
};
</script>

<style scoped>
.scanner-screen {
    display: flex!important;
    justify-content: center;
    align-items: center;
    font-family: monospace;
    overflow: hidden;
    font-size: 1.5em;
}
.backlight-green {
    background-color: rgb(80 254 69 / 30%);
}
.ellipsis-2 {
  display: -webkit-box;
  line-clamp: 2;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
