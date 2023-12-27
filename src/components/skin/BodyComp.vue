<template>
  <div class="body-component" :style="componentStyles" @click="$emit('click', $event)">
    <div v-if="scale" :style="{ fontSize: scale }">
      <slot></slot>
    </div>
    <slot v-else></slot>
  </div>
</template>

<script>
import { unitToSize } from "./util";

export default {
  props: {
    bounds: { type: Object },
  },
  emits: ['click'],
  computed: {
    componentStyles() {
      const convertProperties = [
        "top",
        "bottom",
        "left",
        "right",
        "width",
        "height",
      ];

      // convert "bounds" numbers to CSS units
      return convertProperties.reduce((acc, prop) => {
        acc[prop] = unitToSize(this.bounds[prop]);
        return acc;
      }, {});
    },
    scale() {
      if (!this.bounds.scale) return null;
      return unitToSize(this.bounds.scale);
    },
  },
};
</script>

<style scoped>
.body-component {
  position: absolute;
}

.body-component>*:first-child {
  display: block;
  width: 100%;
  height: 100%;
}
</style>
