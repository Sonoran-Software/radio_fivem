<template>
    <div
      class="draggable"
      :class="{ 'drag-mode': dragEnabled }"
      :style="{
        right: `${posX}px`,
        bottom: `${posY}px`,
        fontSize: `${size}px`,
      }"
      @mousedown="handleStartDrag"
    >
      <div style="position: relative">
        <slot></slot>
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
      // 'move' | 'resize' | null
      dragMode: null,
      prevX: 0,
      prevY: 0,
    },
  }),
  created() {
    document.addEventListener('pointermove', this.handleDoDrag);
    document.addEventListener('mouseup', this.handleStopDrag);
  },
  destroyed() {
    document.removeEventListener('pointermove', this.handleDoDrag);
    document.removeEventListener('mouseup', this.handleStopDrag);
  },
  computed: {
    posX() {
      if (this.value && this.value.length >= 2)
        return this.value[0];
      return 0;
    },
    posY() {
      if (this.value && this.value.length >= 2)
        return this.value[1];
      return 0;
    },
    size() {
      if (this.value && this.value.length >= 3)
        return Math.max(this.value[2], 4); // prevent too small, 1/4 the default size should be fine
      return 16; // default
    }
  },
  methods: {
    handleStartDrag(e) {
      if (!this.dragEnabled) return;
      this.drag.dragMode = e.ctrlKey ? 'resize' : 'move';
      this.drag.prevX = e.clientX;
      this.drag.prevY = e.clientY;
    },
    moveValue(diffX, diffY) {
      const value = [...this.value];
      value[0] -= diffX; // minus because it's based on bottom/right
      value[1] -= diffY;
      return value;
    },
    resizeValue(diffX, diffY) {
      const value = [...this.value];
      if (!value[2]) value[2] = this.size; // add default size if not set
      value[2] -= diffY * 0.02;
      return value;
    },
    handleDoDrag(e) {
      if (!this.drag.dragMode) return;

      const diffX = e.clientX - this.drag.prevX;
      const diffY = e.clientY - this.drag.prevY;

      this.drag.prevX = e.clientX;
      this.drag.prevY = e.clientY;

      const value = this.drag.dragMode === 'move' ? this.moveValue(diffX, diffY) : this.resizeValue(diffX, diffY);
      this.$emit('input', value);
    },
    handleStopDrag(e) {
      this.drag.dragMode = false;
    },
  },
  watch: {
    dragEnabled(newVal) {
      if (!newVal && this.drag.dragMode)
        this.drag.dragMode = null;
    }
  }
};
</script>

<style scoped>
.draggable {
  position: fixed;
}

/* overlay background and border on */
.drag-mode {
  box-sizing: border-box;
  user-select: none;
}

.drag-mode:after {
  content: ' ';
  z-index: 10;
  display: block;
  position: absolute;
  /* height: 100%; */
  top: 0;
  bottom: 0;
  left: 0;
  right: 0;
  background: rgba(0, 0, 0, 0.5);
  border: solid 2px red;
}
</style>
