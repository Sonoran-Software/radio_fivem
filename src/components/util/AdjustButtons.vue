<template>
    <div class="adjust-buttons">
        <div>
            <button @click="$emit('action', 'left')">&larr;</button>
        </div>
        <div>
            <button @click="$emit('action', 'up')">&uarr;</button>
            <button @click="$emit('action', 'down')">&darr;</button>
        </div>
        <div>
            <button @click="$emit('action', 'right')">&rarr;</button>
        </div>
    </div>
</template>

<script>
export default {
    emits: ['action']
};
</script>

<style scoped>
.adjust-buttons {
    display: flex;
    /* justify-content: center; */
    align-items: center;
    gap: 2px;
}
.adjust-buttons button {
    display: block;
    font-size: 16px;
}
</style>
