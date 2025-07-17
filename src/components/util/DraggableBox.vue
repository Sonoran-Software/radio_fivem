<template>
    <div
      ref="dragdiv"
      class="draggable"
      :class="{ 'drag-mode': dragEnabled }"
      :style="{
        right: `${posX}px`,
        bottom: `${posY}px`,
        fontSize: `${size}px`,
      }"
      @pointerdown="handleStartDrag"
    >
      <div
        :class="{ 'no-pointer': dragEnabled }"
      >
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
  emits: ['input'],
  data: () => ({
    drag: {
      dragging: false,
      prevX: 0,
      prevY: 0,
    },
    inc: 0,
  }),
  created() {
    window.addEventListener('pointermove', this.handleDoDrag);
    window.addEventListener('pointerup', this.handleStopDrag);
  },
  destroyed() {
    window.removeEventListener('pointermove', this.handleDoDrag);
    window.removeEventListener('pointerup', this.handleStopDrag);
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
        return this.value[2];
      return 16; // default
    }
  },
  methods: {
    handleStartDrag(e) {
      if (!this.dragEnabled) return;
      e.preventDefault();
      e.target.setPointerCapture(e.pointerId);

      this.drag.dragging = true;
      this.drag.prevX = e.clientX;
      this.drag.prevY = e.clientY;
    },
    moveValue(diffX, diffY, clamp) {
      const value = [...this.value];
      value[0] -= diffX; // minus because it's based on bottom/right
      value[1] -= diffY;
      if (!clamp) return value;

      const rect = this.$refs.dragdiv.getBoundingClientRect();
      // clamp right offset
      value[0] = Math.min(value[0], window.innerWidth - rect.width);
      value[0] = Math.max(value[0], 0);
      // clamp bottom offset
      value[1] = Math.min(value[1], window.innerHeight - rect.height);
      value[1] = Math.max(value[1], 0);

      return value;
    },
    resizeValue(diffX, diffY, clamp) {
      const value = [...this.value];
      if (!value[2]) value[2] = this.size; // add default size if not set

      value[2] -= diffY * 0.02;
      if (!clamp) return value;
      value[2] = Math.max(value[2], 4); // make sure it doesn't get too small

      // clamp by height
      const rect = this.$refs.dragdiv.getBoundingClientRect();
      const scaleFactor = value[2] / this.value[2];
      const newHeight = rect.height * scaleFactor;
      const maxHeight = window.innerHeight - this.value[1];
      if (newHeight > maxHeight)
        value[2] = this.value[2] * (maxHeight / rect.height);

      return value;
    },
    handleDoDrag(e) {
      if (!this.drag.dragging) return;

      const diffX = e.clientX - this.drag.prevX;
      const diffY = e.clientY - this.drag.prevY;

      this.drag.prevX = e.clientX;
      this.drag.prevY = e.clientY;

      const value = e.ctrlKey ?
        this.resizeValue(diffX, diffY, !e.shiftKey) :
        this.moveValue(diffX, diffY, !e.shiftKey);
      this.$emit('input', value);
    },
    handleStopDrag(e) {
      this.drag.dragging = false;
    },
  },
  watch: {
    dragEnabled(newVal) {
      if (!newVal && this.drag.dragging)
        this.drag.dragging = false;
    }
  }
};
</script>

<style scoped>
.draggable {
  position: fixed;
}
.draggable > * {
  position: relative;
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

.no-pointer {
  pointer-events: none;
}
</style>
