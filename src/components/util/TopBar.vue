<template>
    <header class="screen-header">
        <span v-if="!home" class="back" @click="$emit('click-back')">
            <i class="fas fa-arrow-left"></i>
        </span>
        <span v-if="title" class="title">
            {{ title }}
        </span>

        <span v-if="!$slots.default" class="time">
            {{ currTime }}
        </span>
        <slot v-else></slot>
    </header>
</template>

<script>
export default {
    emits: ['click-back'],
    props: {
        home: Boolean,
        title: String,
    },
    computed: {
        currTime() {
            return this.$store.state.inGameTime;
        }
    }
};
</script>

<style scoped>
.screen-header {
    display: flex;
    padding: 0.125em 0.25em; /* 2px 4px */
    background-color: rgb(30, 30, 30);
    justify-content: space-between;
    align-items: center;
}
.screen-header > .back {
    padding: 0 0.25em; /* 0px 4px */
}
.screen-header > .time {
    font-size: 0.75em; /* 12px */
}
</style>
