<template>
    <div class="screen">
        <div class="sc-header">
            Message
        </div>
        <div class="sc-body">
            <div class="sc-status">
                <div class="header">
                    My Status
                </div>
                <div class="content">
                    {{ myStatus }}
                </div>
            </div>
            <div class="sc-spacer">
            </div>
            <div class="sc-container">
                <div class="sc-channel">
                    <div class="header">
                        {{ myZone }}
                    </div>
                    <div class="content">
                        {{ myChannel }}
                    </div>
                </div>
            </div>
            <div class="sc-spacer">
            </div>
            <div class="sc-buttons">
                <div class="sc-button1">
                    Scan Lists
                </div>
                <div class="sc-button2">
                    Contacts
                </div>
                <div class="sc-button3">
                    More
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
                    <div class="sc-btn-new">
                        New
                    </div>
                    <div class="sc-btn-all">
                        All
                    </div>
                </div>
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
