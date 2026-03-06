(() => {
    var child_process = require("child_process");
    var path = require("path");

    function createChildError(message) {
        return new Error(message || "Unzip worker failed without an error message.");
    }

    function getWorkerPath() {
        return path.join(GetResourcePath(GetCurrentResourceName()), "lua", "update", "unzip-child.js");
    }

    function unzipUpdateInChild(file, dest) {
        return new Promise((resolve, reject) => {
            const ignoreFile = path.join(GetResourcePath("sonoranradio_updatehelper"), "ignore.json");
            const worker = child_process.fork(getWorkerPath(), [], {
                windowsHide: true,
                stdio: ["ignore", "pipe", "pipe", "ipc"],
            });

            let settled = false;

            const finish = (err) => {
                if (settled) return;
                settled = true;
                if (err) reject(err);
                else resolve();
            };

            if (worker.stdout) {
                worker.stdout.on("data", (chunk) => {
                    const output = chunk.toString().trim();
                    if (output.length > 0) console.log(output);
                });
            }

            if (worker.stderr) {
                worker.stderr.on("data", (chunk) => {
                    const output = chunk.toString().trim();
                    if (output.length > 0) console.error(output);
                });
            }

            worker.once("message", (message) => {
                if (message && message.ok) {
                    finish();
                    return;
                }

                finish(createChildError(message && message.error));
            });

            worker.once("error", (err) => finish(err));
            worker.once("exit", (code, signal) => {
                if (settled) return;
                if (code === 0) {
                    finish();
                    return;
                }

                const details = signal ? `signal ${signal}` : `code ${code}`;
                finish(createChildError(`Unzip worker exited with ${details}.`));
            });

            worker.send({ file, dest, ignoreFile });
        });
    }

    exports('UnzipFile', (file, dest) => {
        unzipUpdateInChild(file, dest)
            .then(() => emit("UnzipFileComplete", true))
            .catch(err => emit("UnzipFileComplete", false, err && err.message ? err.message : String(err)));
    });
})();
