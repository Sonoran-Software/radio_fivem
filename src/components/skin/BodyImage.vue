<template>
  <img v-if="bodySkin" :src="imgUrl" class="body-image" :style="imgStyle" draggable="false" />
  <div v-else :style="imgStyle"></div>
</template>

<script>
import { unitToSize } from "./util";

export default {
  props: {
    skinId: { type: String },
    bodySkin: { type: Object },
  },
  computed: {
    imgStyle() {
      const width = unitToSize(this.bodySkin?.width);
      const height = unitToSize(this.bodySkin?.height);
      return { width, height };
    },
    imgUrl() {
      if (/^https?:\/\//.test(this.bodySkin.image)) return this.bodySkin.image;
      const url = new URL(
        `/skins/${this.skinId}/${this.bodySkin.image}`,
        `https://cfx-nui-${GetParentResourceName()}`
      );
      return url.toString();
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
