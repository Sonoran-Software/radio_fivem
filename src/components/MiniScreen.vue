<template>
    <div class="top-radio-screen" :class="'backlight-' + $store.getters.connColor">
        <div v-if="!$store.state.connected">
            {{ $store.getters.statusText }}
        </div>
        <div v-else-if="peersTalking.length > 0">
            <div v-for="peer in peersTalking" :key="peer.identity" class="peer-name">{{ peer.displayName ?? 'Undefined' }}</div>
        </div>
        <div v-else>
            <div class="profile-name"><b>{{ $store.getters.channelProfile?.displayName ?? 'CUSTOM' }}</b></div>
            <div>R: {{ $store.getters.recvFreqStr }}</div>
            <div>X: {{ $store.getters.xmitFreqStr }}</div>
        </div>
    </div>
</template>

<script>
export default {
    computed: {
        peersTalking() {
            const peersTalking = [...this.$store.state.peersTalking];
            return peersTalking.sort((a, b) => a.displayName - b.displayName)
        },
    },
};
</script>

<style scoped>
.top-radio-screen {
    display: flex!important;
    justify-content: center;
    align-items: center;
    font-family: monospace;
    font-size: 0.85em;
    overflow: hidden;
}
.top-radio-screen > * {
    max-width: 100%;
}
.profile-name, .peer-name {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.peer-name {
    font-size: 0.85em;
}

/* .backlight-red {
    background-color: rgb(254 69 69 / 30%);
} */

.backlight-gray {
    background-color: unset;
}

.backlight-orange {
    background-color: rgb(217 254 69 / 30%);
}
.backlight-green {
    background-color: rgb(80 254 69 / 30%);
}

.backlight-lightblue {
    background-color: rgb(69 152 254 / 30%);
}
</style>
