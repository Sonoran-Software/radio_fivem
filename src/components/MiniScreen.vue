<template>
    <div class="top-radio-screen" :class="'backlight-' + $store.getters.connColor">
        <div>
            {{ $store.getters.statusText }}
        </div>
        <div>
            {{ $store.getters.freqName || "Custom" }}
        </div>
        <div v-if="$store.state.talkers.length === 0">
            {{ $store.getters.recvFreqStr }} / {{ $store.getters.xmitFreqStr }}
        </div>
        <div v-else>
            <div v-for="t in $store.state.talkers" :key="t.id">
                {{ t.nickname }}
            </div>
        </div>
    </div>
</template>

<script>
export default {};
</script>

<style scoped>
.top-radio-screen {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: space-evenly;
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
