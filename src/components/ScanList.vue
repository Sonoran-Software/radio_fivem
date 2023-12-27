<template>
    <main>
        <top-bar title="Scan List" @click-back="$emit('set-screen', '')">
            <span @click="$emit('add-scanned', '')">&plus;</span>
        </top-bar>

        <div class="sc-body" v-if="$store.state.sublvl <= 1">
            <div class="sc-ch">
                <div class="sc-ch-header">View Only</div>
                <div class="sc-ch-freq">Upgrade to Pro</div>
            </div>
            <div class="sc-ch" v-for="preset in $store.state.presets" :key="preset.display_name">
                <div class="sc-ch-header">{{ preset.display_name }}</div>
                <div class="sc-ch-freq">Recv: {{ preset.freq_recv[0] }}.{{ preset.freq_recv[1] }}<br /> Xmit: {{ preset.freq_xmit[0] }}.{{ preset.freq_xmit[1] }}  </div>
            </div>
        </div>
        <div class="sc-body" v-if="$store.state.sublvl > 1">
            <div class="sc-row" v-on:click="$emit('toggle-scan', '')">
                <div class="sc-row-label">Scan {{ ($store.state.scanning ? "enabled" : "disabled") }}</div>
                <div class="sc-row-icon">
                    <i class="fas fa-toggle-off" v-if="!$store.state.scanning"></i>
                    <i class="fas fa-toggle-on" v-else></i>
                </div>
            </div>
            <div class="sc-row" v-for="freq in $store.state.scanned" :key="freq.id">
                <div class="sc-row-label">{{freq[0]}}.{{freq[1]}}</div>
                <div class="sc-row-icon" v-on:click="$emit('del-scanned', freq)">&times;</div>
            </div>
        </div>
    </main>
</template>

<script>
import TopBar from './util/TopBar.vue';

export default {
    components: {
        TopBar,
    },
    emits: ['set-screen', 'add-scanned', 'toggle-scan', 'del-scanned']
};
</script>

<style scoped>
.sc-body {
    background-color: rgba(62,92,128,1);
}
.sc-row {
    padding: 0.25em; /* 4px */
    display: flex;
    justify-content: space-between;
    border-bottom: rgb(30, 30, 30) solid 1px;
}
.sc-ch {
    padding: 0.25em; /* 4px */
    display: block;
    justify-content: space-between;
    border-bottom: rgb(30, 30, 30) solid 1px;
}
.sc-ch-freq {
    font-size: 0.75em; /* 12px */
    font-size: 13px;
}
</style>
