<template>
  <div class="body-component" :style="componentStyles">
    <slot />
  </div>
</template>

<script>
import { unitToSize } from "./util";

export default {
  props: {
    bounds: { type: Object },
  },
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
  },
};
</script>

<style scoped>
.body-component {
  position: absolute;
}
.body-component > *:first-child {
  display: block;
  width: 100%;
  height: 100%;
}
</style>
