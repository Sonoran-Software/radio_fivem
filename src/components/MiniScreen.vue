<template>
    <div class="top-radio-screen" :class="'backlight-' + $store.getters.connColor">
        <div v-if="!$store.state.connected">
            {{ $store.getters.statusText }}
        </div>
        <div v-else>
            <div class="profile-name"><b>{{ $store.getters.channelProfile?.displayName ?? 'CUSTOM' }}</b></div>
            <div>R: {{ formatFreq($store.getters.freqRecv) }}</div>
            <div>X: {{ formatFreq($store.getters.freqXmit) }}</div>
        </div>
    </div>
</template>

<script>
export default {
    methods: {
        formatFreq(freq) {
            if (!Array.isArray(freq)) return 'NA';
            return `${freq[0]}.${freq[1].toString().padStart(3, '0')}`;
        }
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
.profile-name {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.backlight-gray {
    background-color: unset;
}

.backlight-red {
    background-color: rgb(254 69 69 / 30%);
}

.backlight-yellow {
    background-color: rgb(217 254 69 / 30%);
}

.backlight-green {
    background-color: rgb(80 254 69 / 30%);
}

.backlight-lightblue {
    background-color: rgb(69 152 254 / 30%);
}
</style>
