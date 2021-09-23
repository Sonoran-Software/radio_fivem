<template>
    <div>
        <div v-if="showRadio">
            <div class="radio-container">
                <div id="radio-body" class="radio-body"
                :style="{backgroundImage: 'url(../static/radio-frame.png)'}">
                    <div class="radio-controls">
                        <input type="button" class="ctrl ctrl-panic" />
                        <input type="button" class="ctrl ctrl-prev" onclick="console.log('Previous Clicked');" />
                        <input type="button" class="ctrl ctrl-next" onclick="console.log('Next Clicked');" />
                        <input type="button" class="ctrl ctrl-power" v-on:click="radioPower = !radioPower" />
                    </div>
                    <div class="radio-screen">
                        <div class="radio-content" v-if="radioPower">
                            <Home v-if="currScreen == ''" v-on:set-screen="setScreen($event)" />
                            <Channels v-if="currScreen == 'channels'" v-on:set-screen="setScreen($event)" />
                            <Contacts v-if="currScreen == 'contacts'" v-on:set-screen="setScreen($event)" />
                            <Message v-if="currScreen == 'message'" v-on:set-screen="setScreen($event)" />
                            <Messages v-if="currScreen == 'messages'" v-on:set-screen="setScreen($event)" />
                            <NewMessage v-if="currScreen == 'newmessage'" v-on:set-screen="setScreen($event)" />
                            <ScanList v-if="currScreen == 'scanlist'" v-on:set-screen="setScreen($event)" />
                            <Settings v-if="currScreen == 'settings'" v-on:set-screen="setScreen($event)" />
                        </div>
                        <!-- <iframe id="radio-content" class="radio-content" src="screen.html" width="100%"></iframe> -->
                    </div>
                    <div class="radio-buttons">
                        <input type="button" class="ctrl ctrl-home" @click="setScreen('');" />
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import Home from './components/Home.vue'
import Channels from './components/Channels.vue'
import Message from './components/Message.vue'
import NewMessage from './components/NewMessage.vue'
import ScanList from './components/ScanList.vue'
import Settings from './components/Settings.vue'
import Contacts from './components/Contacts.vue'
import Messages from './components/Messages.vue'

export default {
    components: {
        Home,
        Channels,
        Message,
        NewMessage,
        ScanList,
        Settings,
        Contacts,
        Messages
    },
    data: () => {
        return {
            showRadio: false,
            radioPower: false,
            currScreen: ""
        }
    },
    created() {
        window.addEventListener('keyup', (event) => {
            console.log(event.code);
            switch (event.code) {
                case "Escape":
                    this.postClient({ type: 'hide'});

                    break;
            
                default:
                    break;
            }
        })
    },
    mounted() {
        window.addEventListener('message', (event) => {
            const eventType = event.data.event;
            console.log(event);
            switch (event.data.type) {
                case 'setVisible':
                    this.showRadio = event.data.visibility;
                    break;
                default:
                    break;
            }
        });
    },
    methods: {
        postClient(data, route = "/data") {
            const url = new URL(route, `https://SonoranRadio`);
            const res = fetch(url.toString(), {
                method: "POST",
                body: JSON.stringify(data),
            }).then((res) => {
                if (res.status !== 200)
                    return console.error(`failed request with code: ${res.status}`);

                const msg = res.json().then((data) => {
                    if (data !== "OK") console.error(`failed request with message: ${data}`);
                }).catch((err) => console.log(err));

            }).catch((err) => {
                console.log(err);
            });
        },
        setScreen(name) {
            console.log(name);
            this.currScreen = name;
        }
    }
};
</script>

<style lang="css">
.hidden {
    display: none;
}


.radio-body {
    background-repeat: round;
    width: 250px;
    height: 893px;
    position: fixed;
    right: 30px;
    /* right: 0px; */
    bottom: 0px;
    /* width: 200px;
    height: auto; */
    width: 275px;
    height: 982px;
}

.radio-controls {
    /* background-color: rgba(255,0,0,0.5); */
    margin-top: 482px;
    height: 67px;
    border-width: 0px;
    display: flex;
}

.radio-controls .ctrl:focus {
    outline: none;
}

.radio-controls .ctrl {
    position: relative;
    visibility: visible;
    opacity: 0.0;
    /* for development only */
    /* opacity: 0.3; */
}

.radio-controls .ctrl-panic {
    margin-left: 74px;
    border-radius: 35px;
    width: 30px;
    height: 18px; /* Originally 10px */
    margin-top: 48px; /* Originally 50px */ 
}


.radio-controls .ctrl-prev {
    height: 65px;
    margin-left: 10px;
    width: 22px;
}

.radio-controls .ctrl-next {
    height: 65px; /* Originally 10px */
    margin-left: 0px;
    width: 22px;
}

.radio-controls .ctrl-power {
    height: 45px; /* Originally 10px */
    margin-left: 44px;
    width: 50px;
    margin-top: 28px;
    border-radius: 20px;
}

.radio-screen {
    background-color:black;
    margin: 66px 63px 16px 63px;
    height: 270px;
}

.radio-content {
    border: 0px;
    height: 269px;
    margin: 1px;
    width: 147px;
}

.radio-buttons {
    /* background-color: rgba(0,0,255,0.5); */
    height: 25px;
    margin: 0px 110px;
    display: flex;
}

.radio-buttons .ctrl {
    position: relative;
    visibility: visible;
    opacity: 0.0;
    /* for development only */
    /* opacity: 0.3; */
}

.radio-buttons .ctrl-home {
    width: 100%;
    border-radius: 20px;
}

</style>