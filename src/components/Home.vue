<template>
    <div class="screen">
        <div class="sc-header">
            [] 19:25
        </div>
        <div class="sc-body">
            <div class="sc-status">
                <div class="header">
                    My Name
                </div>
                <div class="content">
                    {{ myName }}
                </div>
            </div>
            <div class="sc-spacer">
            </div>
            <div class="sc-container">
                <div class="sc-channel" v-on:click="$emit('set-screen', 'channels')">
                    <div class="header">
                        {{ freqPreset }}
                    </div>
                    <div class="content">
                        Xmit: {{ freqRecv }} <br>
                        Recv: {{ freqXmit }}
                    </div>
                </div>
            </div>
            <div class="sc-spacer">
            </div>
            <div class="sc-buttons">
                <div class="sc-button1" v-on:click="$emit('set-screen', 'scanlist')">
                    Scan List
                </div>
                <div class="sc-button2" v-on:click="$emit('set-screen', 'contacts')">
                    Contacts
                </div>
                <div class="sc-button3" v-on:click="$emit('set-screen', 'settings')">
                    Setup
                </div>
            </div>
            <div class="sc-spacer">
            </div>
            <div class="sc-message">
                <div class="sc-msg-content">
                    <div class="sc-sender">
                        Clark, Robert
                    </div>
                    <div class="sc-content">
                        On my way
                    </div>
                </div>
                <div class="sc-msg-buttons">
                    <div class="sc-btn-new" v-on:click="$emit('set-screen', 'newmessage')">
                        New
                    </div>
                    <div class="sc-btn-all" v-on:click="$emit('set-screen', 'messages')">
                        All
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>


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

<script>
import vue from 'vue';

export default {
    components: {},
    data() {
        return {
            myName: "Available",
            freqPreset: "Custom Frequency",
            freqXmit: "64.30",
            freqRecv: "64.30"
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
