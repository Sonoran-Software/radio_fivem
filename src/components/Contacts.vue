<template>
    <main>
        <top-bar title="Contacts" @click-back="$emit('set-screen', '')" />
        <div class="sc-body">
            <div class="sc-row" v-for="radio in $store.state.radios" :key="radio.id">
                <div class="sc-row-label" @click="openConversation(radio.id, radio.name)">{{ radio.name }}</div>
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
            myStatus: "Available",
            myZone: "Zone 1",
            myChannel: "Channel 1"
        }
    },
    methods: {
        openConversation(id, name) {
            this.$store.state.recipient.id = id;
            this.$store.state.recipient.name = name;
            this.$emit('set-screen', 'message')
        }
    }

}
</script>

<style scoped>
.sc-body {
    color: white;
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
</style>
