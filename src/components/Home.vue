<template>
    <div class="screen">
        <div class="sc-header">
            <img class="sc-battery" :src="`../static/sradio-battery.png`">
            <div class="sc-time">{{ currTime }}</div>
        </div>
        <div class="sc-body">
            <div class="sc-status">
                <div class="header">
                    My Status
                </div>
                <div class="content">
                    {{ $store.state.statusText }}
                </div>
            </div>
            <div class="sc-spacer">
            </div>
            <div class="sc-container">
                <div class="sc-channel" v-on:click="$emit('set-screen', 'channels')">
                    <div class="header">
                        {{ $store.state.currFreq.name }}
                    </div>
                    <div class="content">
                        Recv: {{ $store.state.currFreq.recv[0] }}.{{ $store.state.currFreq.recv[1] }} <br/>
                        Xmit: {{ $store.state.currFreq.xmit[0] }}.{{ $store.state.currFreq.xmit[1] }}
                    </div>
                </div>
            </div>
            <div class="sc-spacer">
            </div>
            <div class="sc-buttons">
                <div class="sc-button" v-on:click="$emit('set-screen', 'scanlist')">
                    <i class="fas fa-file-medical-alt"></i>
                    <span class="sc-button-label">Scan List</span>
                </div>
                <div class="sc-button" v-on:click="$emit('set-screen', 'contacts')" style="display: none;">
                    <i class="fas fa-address-book"></i>
                    <span class="sc-button-label">Contacts</span>
                </div>
                <div class="sc-button" v-on:click="$emit('set-screen', 'settings')" style="display: none;">
                    <i class="fas fa-cog"></i>
                    <span class="sc-button-label">Setup</span>
                </div>
            </div>
            <div class="sc-spacer">
            </div>
            <div class="sc-message" style="display: none;">
                <div class="sc-msg-content">
                    <div class="sc-sender">
                        Clark, Robert
                    </div>
                    <div class="sc-content">
                        On my way
                    </div>
                </div>
                <div class="sc-msg-buttons">
                    <div class="sc-msg-btn" v-on:click="$emit('set-screen', 'newmessage')">
                        <i class="fas fa-address-book"></i>
                        <span class="sc-button-label">New</span>
                    </div>
                    <div class="sc-msg-btn" v-on:click="$emit('set-screen', 'messages')">
                        <i class="fas fa-address-book"></i>
                        <span class="sc-button-label">All</span>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import vue from 'vue';

export default {
    props: [
        "config"
    ],
    components: {},
    data() {
        return {
            currTime: "00:00"
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
    padding: 3px 6px 2px 3px;
    background-color: rgba(30,30,30,1);
    display: flex;
    flex-direction: row;
    justify-content: space-between;
    align-items: center;
    justify-content: flex-end;
}
.sc-icons {
    display: flex;
    flex-direction: row;
    align-items: center;
}
.sc-battery {
    height: 11px;
    padding-right: 5px;
}
.sc-time {
    font-size: 12px;
}
.sc-brand {
    font-size: 12px;
}
.sc-logo {
    height: 11px;
    padding-top: 1px;
}
.sc-body {
    color: white;
    background-color: rgba(62,92,128,1);
    margin: 0px 5px;
}
.sc-status {
    margin: 7px 0px 0px 0px;
    padding: 3px 3px 3px 5px;
}
.sc-status .header {
    font-size: 14px;
    color: rgba(255,255,255,0.7)
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
    font-size: 12px;
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
.sc-button {
    display: flex;
    flex-direction: column;
    align-items: center;
}
.sc-button i {
    font-size: 20px;
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
.sc-msg-button {
    display: flex;
    flex-direction: column;
    align-items: center;
}
.sc-msg-button i {
    font-size: 20px;
}
</style>
