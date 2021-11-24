<template>
    <div class="screen">
        <div class="sc-header">
            <div class="back" v-on:click="$emit('set-screen', '')">
                <i class="fas fa-arrow-left"></i>
            </div>
            <div class="title">
                Contacts
            </div>
            <div class="search" style="visibility: hidden !important;">
                &#128269;
            </div>
        </div>
        <div class="sc-body">
            <div class="sc-row" v-for="radio in $store.state.radios" :key="radio.id">
                <div class="sc-row-label">{{ radio.name }}</div>
            </div>
        </div>
    </div>
</template>

<script>
import vue from 'vue';

export default {
    components: {},
    data() {
        return {
            myStatus: "Available",
            myZone: "Zone 1",
            myChannel: "Channel 1"
        }
    },
    mounted() {
        window.addEventListener('message', (event) => {
            const eventType = event.data.event;
            console.log(event);
            if (event.data.type === 'hello') {
                console.log('world!');
                this.showRadio = true;
            }
        });
    },
    methods: {

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
    display: flex;
    justify-content: space-between;
    border-bottom: rgb(30, 30, 30) solid 1px;
}
.sc-row-label {
    font-size: 14px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
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
