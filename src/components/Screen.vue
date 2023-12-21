<template>
    <div class="screen" :class="{ 'on': on }">
        <slot></slot>
    </div>
</template>

<script>
export default {
    props: {
        on: Boolean,
    },
};
</script>

<style scoped>
.screen {
    background-color: black;
    height: 100%;
    font-family: system-ui;
    color: white;
    overflow-x: hidden;
    overflow-y: scroll;
}
.screen.on {
    background-color: rgb(122, 160, 207);
}
.screen::-webkit-scrollbar {
    display: none;
}
</style>
