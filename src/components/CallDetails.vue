<template>
    <main>
        <top-bar title="Call Details" @click-back="$emit('set-screen', '')" />
        <div class="sc-body">
            <div class="sc-row">
                <div class="sc-row-label">Code:</div>
                <div class="sc-row-text">{{ $store.state.call.code }}</div>
                <div class="sc-row-label">Title:</div>
                <div class="sc-row-text">{{ $store.state.call.title }}</div>
                <div class="sc-row-label">Location:</div>
                <div class="sc-row-text">{{ $store.state.call.location }}</div>
                <div class="sc-row-label">Description:</div>
                <div class="sc-row-text">{{ $store.state.call.description }}</div>
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
    emits: ['set-screen'],
    data() {
        return {
            callCode: "",
            callTitle: "",
            callLocation: "",
            callDescription: ""
        }
    },
}
</script>

<style scoped>
.sc-body {
    color: white;
    background-color: rgba(62, 92, 128, 1);
}

.sc-row {
    padding: 0.1875em 0.25em; /* 3px 4px */
    justify-content: space-between;
    border-bottom: rgb(30, 30, 30) solid 1px;
}

.sc-row-text {
    font-size: 0.75em; /* 12px */
}</style>
