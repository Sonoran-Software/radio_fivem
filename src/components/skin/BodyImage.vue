<template>
  <img v-if="bodySkin" :src="bodySkin.image" class="body-image" :style="imgStyle" draggable="false" />
  <div v-else :style="imgStyle"></div>
</template>

<script>
import { unitToSize } from "./util";

export default {
  props: {
    bodySkin: { type: Object },
  },
  computed: {
    imgStyle() {
      const width = unitToSize(this.bodySkin?.width);
      const height = unitToSize(this.bodySkin?.height);
      return { width, height };
    },
  },
};
</script>

<style scoped>
.body-image {
  position: relative;
  z-index: 15;
  pointer-events: none;
}
</style>
