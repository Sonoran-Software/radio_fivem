<template>
    <main>
        <top-bar title="Channels" @click-back="$emit('set-screen', '')" />
        <div class="sc-body" v-if="!$store.state.connected">
            <div class="sc-ch">
                <div class="sc-ch-header">Radio Not Connected</div>
                <div class="sc-ch-freq">Your radio is not connected to TeamSpeak</div>
            </div>
        </div>
        <div class="sc-body" v-else-if="$store.state.sublvl === 0">
            <div class="sc-ch">
                <div class="sc-ch-header">View Only</div>
                <div class="sc-ch-freq">Upgrade to Plus</div>
            </div>
            <div class="sc-ch" v-for="preset in $store.state.presets" :key="preset.display_name">
                <div class="sc-ch-header">{{ preset.display_name }}</div>
                <div class="sc-ch-freq">Recv: {{ preset.freq_recv[0] }}.{{ preset.freq_recv[1] }}<br /> Xmit: {{ preset.freq_xmit[0] }}.{{ preset.freq_xmit[1] }}  </div>
            </div>
        </div>
        <div v-else class="sc-body">
            <div class="sc-row" v-on:click="$emit('set-screen', 'channel')">
                <div class="sc-row-label">Custom</div>
                <div class="sc-row-icon"><i class="fas fa-arrow-right"></i></div>
            </div>
            <div class="sc-ch" v-for="preset in $store.state.presets" :key="preset.display_name" v-on:click="setFrequency(preset.freq_xmit, preset.freq_recv)">
                <div class="sc-ch-header">{{ preset.display_name }}</div>
                <div class="sc-ch-freq">Recv: {{ preset.freq_recv[0] }}.{{ preset.freq_recv[1] }}<br /> Xmit: {{ preset.freq_xmit[0] }}.{{ preset.freq_xmit[1] }}  </div>
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
    methods: {
        setFrequency(xmit, recv) {
            this.$store.commit('setFreqs', {
                xmit,
                recv
            });
            this.$emit('set-frequency','');
            this.$emit('set-screen','');
        }
    },
}
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
}
</style>
