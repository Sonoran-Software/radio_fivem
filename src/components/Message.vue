<template>
    <main>
        <top-bar title="Messaging" @click-back="$emit('set-screen', '')" />

        <div class="sc-body">
            <div class="sc-row">
                <div class="sc-row-label">{{ $store.state.recipient.name }}</div>
            </div>
            <div class="sc-row">
                <input type="text" class="sc-row-input"
                    @keyup.enter="$emit('send-message', { recipient: $store.state.recipient.id, payload: { message: messageText } })"
                    v-model="messageText">
            </div>
            <div class="sc-row" v-for="conversation in $store.state.conversations.filter((obj) => {
                return obj.sender === $store.state.recipient.name
            })" :key="conversation.sender">
                <div class="sc-row-text"> {{ conversation.payload.message }}</div>
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
    data() {
        return {
            messageText: "",
            myStatus: "Available",
            myZone: "Zone 1",
            myChannel: "Channel 1"
        }
    },
}
</script>

<style scoped>
.sc-body {
    background-color: rgba(62, 92, 128, 1);
}

.sc-row {
    padding: 0.25em; /* 4px */
    display: flex;
    justify-content: space-between;
    border-bottom: rgb(30, 30, 30) solid 1px;
}

.sc-row-label {
    font-size: 0.875em; /* 14px */
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.sc-row-input {
    box-sizing: border-box;
    width: 100%;
}</style>
