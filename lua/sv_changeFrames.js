const fs = require("fs");
const path = require("path");

// Synchronously read only top‑level directories under skins/
function getAvailableFrames(skinsDir) {
	return fs
		.readdirSync(skinsDir, { withFileTypes: true })
		.filter((dirent) => dirent.isDirectory())
		.map((dirent) => dirent.name);
}

exports("GetAvailableFrames", getAvailableFrames);