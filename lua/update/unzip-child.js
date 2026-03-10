(() => {
    var unzipper = require("unzipper");
    var { minimatch } = require("minimatch");
    var fs = require("fs");
    var path = require("path");

    function readIgnore(ignoreFile) {
        if (!ignoreFile || !fs.existsSync(ignoreFile)) return [];

        const parsed = JSON.parse(fs.readFileSync(ignoreFile, "utf8"));
        return Array.isArray(parsed) ? parsed : [];
    }

    function ensureDirectory(fullPath) {
        let shouldCreate = !fs.existsSync(fullPath);
        if (!shouldCreate && !fs.statSync(fullPath).isDirectory()) {
            fs.rmSync(fullPath, { recursive: true, force: true });
            shouldCreate = true;
        }

        if (shouldCreate) {
            fs.mkdirSync(fullPath, { recursive: true });
        }
    }

    function unzipUpdate(file, dest, ignoreFile) {
        const ignore = readIgnore(ignoreFile);

        const isIgnored = (filePath) => {
            for (const pattern of ignore)
                if (minimatch(filePath, pattern))
                    return true;
            return false;
        };

        return new Promise((resolve, reject) => {
            fs.createReadStream(file).pipe(unzipper.Parse()).on("entry", (entry) => {
                const entryPath = entry.path;
                const type = entry.type;
                const fullPath = path.resolve(dest, entryPath);

                if (isIgnored(entryPath)) return void entry.autodrain();

                if (type === "Directory") {
                    ensureDirectory(fullPath);
                    return void entry.autodrain();
                }

                ensureDirectory(path.dirname(fullPath));
                entry.pipe(fs.createWriteStream(fullPath));
            })
            .on("close", resolve)
            .on("error", reject);
        });
    }

    function sendResult(message, exitCode) {
        if (typeof process.send === "function") {
            process.send(message, () => process.exit(exitCode));
            return;
        }

        process.exit(exitCode);
    }

    process.once("message", ({ file, dest, ignoreFile }) => {
        unzipUpdate(file, dest, ignoreFile)
            .then(() => sendResult({ ok: true }, 0))
            .catch((err) => sendResult({ ok: false, error: err && err.message ? err.message : String(err) }, 1));
    });
})();
