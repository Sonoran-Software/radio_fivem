<template>
    <main>
        <top-bar :title="$store.getters.statusText" home />
        <div class="sc-body">
            <div class="section sc-status" @click="$emit('set-screen', 'calldetails')">
                <div class="sc-status-text">
                    <div class="header">
                        My Status
                    </div>
                    <div>
                        {{ $store.getters.statusText }}
                    </div>
                </div>
                <div>
                    <i class="fas fa-clipboard-list"></i>
                </div>
            </div>

            <div class="sc-container" :style="{ backgroundColor: $store.getters.connColor }">
                <div class="section sc-channel">
                    <div class="header">
                        {{ $store.getters.freqName || "Custom" }}
                    </div>
                    <div class="sc-channel-text">
                        <div v-if="$store.state.talkers.length === 0" class="content">
                            Recv: {{ recvFreq }}<br/>
                            Xmit: {{ xmitFreq }}<br/>
                        </div>
                        <div v-else class="content">
                            <div v-for="t in $store.state.talkers" :key="t.id">
                                {{ t.nickname }}
                            </div>
                        </div>
                        <div class="sc-channel-icons">
                            <i class="fas fa-house-user" v-on:click="$emit('go-home', 0)"></i>
                            <i class="fas fa-sliders-h" v-on:click="$emit('set-screen', 'channels')"></i>
                        </div>
                    </div>

                </div>
            </div>

            <div class="section sc-buttons">
                <div class="sc-button" v-on:click="$emit('set-screen', 'scanlist')">
                    <i class="fas fa-file-medical-alt"></i>
                    <span class="sc-button-label">Scan List</span>
                </div>
                <div class="sc-button" v-on:click="$emit('set-screen', 'contacts')">
                    <i class="fas fa-address-book"></i>
                    <span class="sc-button-label">Contacts</span>
                </div>
                <div class="sc-button" v-on:click="$emit('set-screen', 'settings')">
                    <i class="fas fa-cog"></i>
                    <span class="sc-button-label">Config</span>
                </div>
            </div>

            <div class="section sc-message" v-if="lastConversation">
                <div class="sc-msg-content" @click="openConversation(lastConversation)">
                    <div class="sc-sender">
                        {{ lastConversation.sender }}
                    </div>
                    <div class="sc-content">
                        {{ lastConversation.payload.message }}
                    </div>
                </div>
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
    computed: {
        recvFreq() {
            return this.$store.getters.recvFreqStr;
        },
        xmitFreq() {
            return this.$store.getters.xmitFreqStr;
        },
        lastConversation() {
            const convos = this.$store.state.conversations;
            if (convos.length === 0) return null;
            return convos[convos.length - 1];
        }
    },
    methods: {
        freqToString(freq) {
            if (freq[0] === 'xxx') return 'N/A';
            return `${freq[0]}.${freq[1].toString().padStart(3, '0')}MHz`
        },
        openConversation(conversation) {
            this.$store.state.recipient.id = conversation.senderid;
            this.$store.state.recipient.name = conversation.sender;
            this.$emit('set-screen', 'message')
        }
    }

}
</script>

<style scoped>
.sc-body {
    display: flex;
    flex-direction: column;
    padding: 0.3125em; /* 5px */
    gap: 0.1875em; /* 3px */
}
.sc-body .section {
    background-color: rgb(62, 92, 128);
}

.sc-status {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.125em 0.25em; /* 2px 4px */
}
.sc-status-text > .header {
    font-size: 0.75em;
    color: #d0d0d0;
}

.sc-container {
    background-color: white;
}
.sc-channel {
    margin-left: 0.75em; /* 12px */
    padding: 0.125em 0.25em; /* 2px 4px */
}
.sc-channel-icons {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 0.125em 0.25em; /* 2px 4px */
    gap: 0.125em; /* 2px */
}
.sc-channel-text {
    display: flex;
    flex-direction: row;
    justify-content: space-between;
    align-items: center;
}
.sc-channel .header {
    font-size: 0.75em;
    color: #d0d0d0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.sc-channel .content {
    font-size: 0.875em; /* 14px */
}

.sc-buttons {
    padding: 0.5em 0.25em; /* 8px 4px */
    display: flex;
    justify-content: space-around;
    align-items: flex-end;
    flex-wrap: nowrap;
}
.sc-button {
    display: flex;
    flex-direction: column;
    align-items: center;
}
.sc-button i {
    font-size: 1.25em; /* 20px */
}
.sc-button .sc-button-label {
    font-size: 0.625em; /* 10px */
}
.sc-message .sender {
    font-size: 0.875em; /* 14px */
}
.sc-message .content {
    font-size: 0.75em; /* 12px */
    color: #d0d0d0;
}
.sc-msg-content {
    padding: 0.25em 0.25em; /* 4px 4px */
}
</style>
