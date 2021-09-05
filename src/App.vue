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
                        <Screen v-if="radioPower" id="radio-content" />
                        <!-- <iframe id="radio-content" class="radio-content" src="screen.html" width="100%"></iframe> -->
                    </div>
                    <div class="radio-buttons">
                        <input type="button" class="ctrl ctrl-home" onclick="document.getElementById('radio-content').contentWindow.location.reload();" />
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import Screen from './components/Screen.vue'



    //   if (eventType !== undefined && typeof this['on' + eventType] === 'function') {
    //     this['on' + eventType](event.data)
    //   } else if (event.data.show !== undefined) {
    //     // Toggle phone
    //     store.commit('SET_PHONE_VISIBILITY', event.data.show)
    //   }

export default {
    components: {
        Screen
    },
    data: () => {
        return {
            showRadio: false,
            radioPower: false,
        }
    },
    mounted() {
        window.addEventListener('message', (event) => {
            const eventType = event.data.event;
            console.log(event);
            if (event.data.type === 'show') {
                this.showRadio = true;
            }
        });
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