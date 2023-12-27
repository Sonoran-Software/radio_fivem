<template>
    <main>
        <top-bar title="Custom Freq." @click-back="$emit('set-screen', 'channels')" />

        <div class="sc-body">
            <label class="row-input">
                Recv:
                <input type="text" v-model="recvInput" />
            </label>
            <label class="row-input">
                Xmit:
                <input type="text" v-model="xmitInput" />
            </label>
            <input type="button" class="sc-row-button" value="Set Frequency" v-on:click="setFrequency()">
        </div>
    </main>
</template>

<script>
import TopBar from './util/TopBar.vue';

export default {
    components: {
        TopBar,
    },
    props: ["presets"],
    data() {
        return {
            xmitInput: "",
            recvInput: ""
        }
    },
    mounted() {
        this.xmitInput = this.$store.state.currFreq.xmit[0] + "." + this.$store.state.currFreq.xmit[1];
        this.recvInput = this.$store.state.currFreq.recv[0] + "." + this.$store.state.currFreq.recv[1];
    },
    methods: {
        inRange(val) {
            return ((val >= 30 && val <= 50) || (val >= 150 && val <= 174));
        },
        inSecondRange(val) {
            return (val >= 0 && val <= 999);
        },
        setFrequency() {
            if (!this.inRange(this.xmitInput.split(".")[0]) || !this.inSecondRange(this.xmitInput.split(".")[1])) {
                console.log("Xmit Value Invalid");
                this.xmitInput += "(invalid)";
                return;
            }
            if (!this.inRange(this.recvInput.split(".")[0]) || !this.inSecondRange(this.recvInput.split(".")[1])) {
                console.log("Recv Value Invalid");
                this.recvInput += "(invalid)";
                return;
            }
            this.$store.state.currFreq.xmit[0] = parseInt(this.xmitInput.split(".")[0]);
            this.$store.state.currFreq.xmit[1] = parseInt(this.xmitInput.split(".")[1]);
            this.$store.state.currFreq.recv[0] = parseInt(this.recvInput.split(".")[0]);
            this.$store.state.currFreq.recv[1] = parseInt(this.recvInput.split(".")[1]);
            this.$emit('set-frequency','')
            this.$emit('set-screen','')
        }
    }

}
</script>

<style scoped>
.sc-body {
    background-color: rgba(62,92,128,1);
    padding: 0.1875em 0.25em; /* 3px 4px */

    display: flex;
    flex-direction: column;
    gap: 0.125em; /* 2px */
}
.row-input input {
    box-sizing: border-box;
    width: 100%;
}
</style>
