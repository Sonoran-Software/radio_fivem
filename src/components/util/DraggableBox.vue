<template>
  <div>
    <div
      class="draggable"
      :class="{ 'drag-mode': dragEnabled }"
      :style="`bottom: ${posY}px; right: ${posX}px`"
      @mousedown="handleStartDrag"
    >
      <slot />
    </div>
  </div>
</template>

<script>
export default {
  props: {
    value: Array,
    dragEnabled: Boolean,
  },
  data: () => ({
    drag: {
      isDragging: false,
      prevX: 0,
      prevY: 0,
    },
  }),
  created() {
    document.addEventListener('pointermove', this.handleDoDrag.bind(this));
    document.addEventListener('mouseup', this.handleStopDrag.bind(this));
  },
  destroyed() {
    document.removeEventListener('pointermove', this.handleDoDrag.bind(this));
    document.removeEventListener('mouseup', this.handleStopDrag.bind(this));
  },
  computed: {
    posX() {
      if (this.value && this.value.length === 2)
        return this.value[0];
      return 0;
    },
    posY() {
      if (this.value && this.value.length === 2)
        return this.value[1];
      return 0;
    }
  },
  methods: {
    updateValue(newVal) {
      this.$emit('input', newVal);
    },
    handleStartDrag(e) {
    if (!this.dragEnabled) return;
      this.drag.isDragging = true;
      this.drag.prevX = e.clientX;
      this.drag.prevY = e.clientY;
    },
    handleDoDrag(e) {
      if (!this.drag.isDragging) return;

      const diffX = e.clientX - this.drag.prevX;
      const diffY = e.clientY - this.drag.prevY;
      this.drag.prevX = e.clientX;
      this.drag.prevY = e.clientY;

      this.$emit('input', [this.posX - diffX, this.posY - diffY]);
    },
    handleStopDrag(e) {
      this.drag.isDragging = false;
    },
  },
  watch: {
    dragEnabled(newVal) {
      if (!newVal && this.drag.dragEnabled)
        this.drag.dragEnabled = false;
    }
  }
};
</script>

<style scoped>
.draggable>* {
  overflow: hidden;
}

.draggable {
  position: fixed;
}

/* overlay background and border on */
.drag-mode {
  box-sizing: border-box;
}

.drag-mode:after {
  content: ' ';
  z-index: 10;
  display: block;
  position: absolute;
  height: 100%;
  top: 0;
  left: 0;
  right: 0;
  background: rgba(0, 0, 0, 0.5);
  border: solid 2px red;
}
</style>
