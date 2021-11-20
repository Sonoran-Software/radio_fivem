<template>
    <div class="screen">
        <div class="sc-header">
            <div class="back" v-on:click="$emit('set-screen', '')">
                <i class="fas fa-arrow-left"></i>
            </div>
            <div class="title">
                Call Details
            </div>
            <div class="search" style="visibility: hidden !important;">
                &#128269;
            </div>
        </div>
        <div class="sc-body">
            <div class="sc-row">
                <div class="sc-row-label">Code:</div><div class="sc-row-text">{{ $store.state.call.code }}</div>
                <div class="sc-row-label">Title:</div><div class="sc-row-text">{{ $store.state.call.title }}</div>
                <div class="sc-row-label">Location:</div><div class="sc-row-text">{{ $store.state.call.location }}</div>
                <div class="sc-row-label">Description:</div><div class="sc-row-text">{{ $store.state.call.description }}</div>
                <!--<input type="button" class="sc-row-button" value="Set Frequency" v-on:click="setFrequency()">-->
            </div>
        </div>
    </div>
</template>

<script>
import vue from 'vue';

export default {
    props: ["presets"],
    components: {},
    data() {
        return {
            callCode: "",
            callTitle: "",
            callLocation: "",
            callDescription:""
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
.screen {
    background-color: rgba(122,160,207,1);
    height: 100%;
    font-family: system-ui;
}
.sc-header {
    text-align: right;
    color: white;
    padding: 3px 6px 2px 0px;
    background-color: rgba(30,30,30,1);
    display: flex;
    flex-direction: row;
    justify-content: space-around;
    align-items: center;
}
.sc-header .back {
    padding: 0px 5px;
}
.sc-body {
    color: white;
    background-color: rgba(62,92,128,1);
    /* margin: 0px 5px; */
}
.sc-row {
    padding: 3px 3px 3px 5px;
    justify-content: space-between;
    border-bottom: rgb(30, 30, 30) solid 1px;
}
.sc-row-label {
    font-size: 16px;
}
.sc-row-text {
    font-size: 12px;
}
.sc-row-input {
    width: 130px;
}
.sc-row-button {
    width: 138px;
}
.sc-status {
    margin: 7px 0px 0px 0px;
    padding: 3px 3px 3px 5px;
}
.sc-status .header {
    font-size: 14px;
    color: rgba(255,255,255,0.7)
}
.sc-status .content {

}
.sc-spacer {
    height: 5px;
    background-color: rgba(122,160,207,1);
}
.sc-container {
    background-color: white;
}
.sc-channel {
    background-color: rgba(62,92,128,1);
    margin: 0px 0px 0px 10px;
    padding: 3px 5px;
    height: 60px;
}
.sc-channel .header {
    font-size: 14px;
    color: rgba(255,255,255,0.7)
}
.sc-buttons {
    background-color: rgba(62,92,128,1);
    margin: 0px;
    padding: 3px 5px;
    height: 40px;
    font-size: 10px;
    display: flex;
    flex-direction: row;
    justify-content: space-around;
    flex-wrap: nowrap;
    align-items: flex-end;
}
.sc-sender {
    font-size: 14px;
}
.sc-content {
    font-size: 12px;
    color: rgba(255,255,255,0.7);

}
.sc-msg-content {
    padding: 3px 3px 3px 5px;
}
.sc-msg-buttons {
    display: flex;
    flex-direction: row;
    flex-wrap: nowrap;
    justify-content: space-around;
    font-size: 14px;
}
</style>
