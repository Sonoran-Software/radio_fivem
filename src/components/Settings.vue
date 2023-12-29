<template>
    <main>
        <top-bar title="Settings" @click-back="$emit('set-screen', '')" />

        <div class="sc-body">
            <div class="sc-row" @click="$emit('set-help', !helpEnabled)">
                <div class="sc-row-label">Button Help</div>
                <div class="sc-row-icon">
                    <i v-if="helpEnabled" class="fas fa-toggle-on"></i>
                    <i v-else class="fas fa-toggle-off"></i>
                </div>
            </div>
            <div class="sc-row" @click="$emit('enable-drag', true)">
                <div class="sc-row-label">Reposition UI</div>
            </div>
            <div v-for="(skin, i) in skinOptions" :key="i" class="sc-row" @click="setSkin(skin.id)">
                <div class="sc-row-label">{{ skin.name }}</div>
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
    props: { helpEnabled: Boolean, skinOptions: Array, },
    emits: ['set-screen', 'set-help', 'enable-drag', 'set-skin-id'],
    methods: {
        setSkin(skinId) {
            this.$emit('set-skin-id', skinId);
        }
    }
}
</script>

<style scoped>
.sc-body {
    background-color: rgba(62, 92, 128, 1);
}

.sc-row {
    padding: 0.25em;
    /* 4px */
    display: flex;
    justify-content: space-between;
    border-bottom: rgb(30, 30, 30) solid 1px;
    cursor: pointer;
}

.sc-row-label {
    font-size: 0.875em;
    /* 14px */
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}</style>
