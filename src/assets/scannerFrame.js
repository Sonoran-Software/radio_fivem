import scannerPng from "./scanner.png";

const imageUrl = new URL(scannerPng, window.location.href);
export default {
  type: "scanner",
  key: "scanner",
  body: { image: imageUrl.toString(), width: 25 },
  controls: [
    {
      action: "scanner_power",
      bottom: 5.25,
      right: 2.75,
      width: 1.5,
      height: 1.5,
    },
    {
      action: "scanner_prev",
      bottom: 7.5,
      right: 6.5,
      width: 2.5,
      height: 5.5,
    },
    {
      action: "scanner_next",
      bottom: 7.5,
      right: 4,
      width: 2.5,
      height: 5.5,
    },
  ],
  scannerScreen: {
    top: 6.25,
    height: 4.5,
    left: 4.5,
    right: 4.5,
    zIndex: 25,
  },
};
