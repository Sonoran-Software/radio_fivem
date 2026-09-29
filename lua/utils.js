(() => {
    const https = require("https");
    const url = require("url");
    const zlib = require("zlib");
    const fs = require("fs");
    const path = require("path");

    function byteCount(s) {
        return encodeURI(s).split(/%..|./).length - 1;
    }

    function hasHeader(headers, name) {
        const normalized = name.toLowerCase();
        return Object.keys(headers || {}).some((key) => key.toLowerCase() === normalized);
    }

    function setVersionHeaders(headers) {
        const version = GetResourceMetadata(GetCurrentResourceName(), "version", 0);
        if (!version) {
            return;
        }

        if (!hasHeader(headers, "X-SonoranRadio-Version")) {
            headers["X-SonoranRadio-Version"] = version;
        }
        if (!hasHeader(headers, "X-FiveM-Resource-Version")) {
            headers["X-FiveM-Resource-Version"] = version;
        }
    }

    exports('HandleHttpRequest', (dest, callback, method, data, headers) => {
        emit("SonoranRadio::core:writeLog", "debug", "[http] to: " + dest + " - data: " + dest, JSON.stringify(data));
        const urlObj = url.parse(dest)
        const normalizedMethod = (method || "GET").toUpperCase();
        const requestHeaders = Object.assign({}, headers || {});
        const options = {
            hostname: urlObj.hostname,
            path: urlObj.path || urlObj.pathname,
            method: normalizedMethod,
            headers: requestHeaders
        }
        if (data !== undefined && data !== null && data !== "") {
            if (!options.headers['Content-Type']) {
                options.headers['Content-Type'] = 'application/json'
            }
        }
        setVersionHeaders(options.headers);
        const req = https.request(options, (res) => {
            const chunks = [];
            res.on('data', (d) => {
                chunks.push(Buffer.from(d))
            }),
            res.on('end', () => {
                const body = Buffer.concat(chunks);
                const encoding = String(res.headers["content-encoding"] || "").toLowerCase();
                const finish = (decoded) => callback(res.statusCode, decoded, res.headers);

                if (encoding.includes("gzip")) {
                    zlib.gunzip(body, (error, decoded) => {
                        if (error) {
                            console.debug("HTTP gzip decode failed: " + JSON.stringify(error));
                            finish(body.toString());
                            return;
                        }
                        finish(decoded.toString());
                    });
                    return;
                }

                if (encoding.includes("deflate")) {
                    zlib.inflate(body, (error, decoded) => {
                        if (error) {
                            console.debug("HTTP deflate decode failed: " + JSON.stringify(error));
                            finish(body.toString());
                            return;
                        }
                        finish(decoded.toString());
                    });
                    return;
                }

                finish(body.toString());
            })
          })

        req.on('error', (error) => {
            let ignore_ids = ["EAI_AGAIN", "ETIMEOUT", "ENOTFOUND"]
            if (!ignore_ids.includes(error.code))
                console.debug("HTTP error caught: " + JSON.stringify(error));
            callback(0, JSON.stringify({
                error: "HTTP_REQUEST_FAILED",
                code: error.code || "UNKNOWN",
                message: error.message || "HTTP request failed.",
                host: error.host || urlObj.hostname || null,
                port: error.port || urlObj.port || 443,
                path: error.path || null
            }), {"content-type": "application/json"});
        })
        if (data !== undefined && data !== null && data !== "") {
            req.write(data);
        }
        req.end();
    });

    // Synchronously read only top‑level directories under skins/
    function getAvailableFrames(skinsDir) {
        if (!fs.existsSync(skinsDir)) {
            return [];
        }
        return fs
            .readdirSync(skinsDir, { withFileTypes: true })
            .filter((dirent) => dirent.isDirectory())
            .map((dirent) => dirent.name);
    }
    exports("GetAvailableFrames", getAvailableFrames);

    const imageTypes = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".gif": "image/gif"
    };

    function scanLegacySkins(skinsDir) {
        const result = { exists: false, skins: [], errors: [] };
        if (!fs.existsSync(skinsDir)) {
            return JSON.stringify(result);
        }
        result.exists = true;

        for (const dirent of fs.readdirSync(skinsDir, { withFileTypes: true })) {
            if (!dirent.isDirectory()) continue;
            const legacySkinId = dirent.name;
            if (!/^[A-Za-z0-9_-]{1,64}$/.test(legacySkinId)) {
                result.errors.push(`Invalid legacy skin folder name: ${legacySkinId}`);
                continue;
            }

            const skinDir = path.resolve(skinsDir, legacySkinId);
            const configPath = path.join(skinDir, "skin.json");
            if (!fs.existsSync(configPath)) {
                result.errors.push(`${legacySkinId}: skin.json is missing`);
                continue;
            }

            try {
                const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
                if (!config || typeof config !== "object" || !Array.isArray(config.frames)) {
                    throw new Error("skin.json must contain a frames array");
                }
                const unsupportedType = config.frames.find((frame) =>
                    !frame || !["portable", "vehicle", "hud", "scanner"].includes(frame.type)
                );
                if (unsupportedType) {
                    throw new Error(`unsupported frame type: ${unsupportedType.type || "unknown"}`);
                }
                const frames = config.frames.filter((frame) =>
                    frame && ["portable", "vehicle", "hud", "scanner"].includes(frame.type)
                );
                if (!frames.some((frame) => frame.type === "portable")) {
                    throw new Error("an on-foot/portable frame is required");
                }

                const images = [];
                const seenImages = new Set();
                for (const frame of frames) {
                    const image = frame.body && frame.body.image;
                    if (typeof image !== "string" || image.trim() === "") {
                        throw new Error(`${frame.type} frame body image is missing`);
                    }
                    if (/^https:\/\//i.test(image)) continue;
                    if (/^[a-z]+:\/\//i.test(image)) {
                        throw new Error(`unsupported frame image URL: ${image}`);
                    }

                    const normalizedImage = image.replace(/\\/g, "/");
                    const absoluteImage = path.resolve(skinDir, normalizedImage);
                    const relativeImage = path.relative(skinDir, absoluteImage);
                    if (relativeImage.startsWith("..") || path.isAbsolute(relativeImage)) {
                        throw new Error(`frame image escapes its skin folder: ${image}`);
                    }
                    if (!fs.existsSync(absoluteImage) || !fs.statSync(absoluteImage).isFile()) {
                        throw new Error(`frame image is missing: ${image}`);
                    }
                    const extension = path.extname(absoluteImage).toLowerCase();
                    const contentType = imageTypes[extension];
                    if (!contentType) {
                        throw new Error(`unsupported frame image format: ${image}`);
                    }
                    if (!seenImages.has(normalizedImage)) {
                        seenImages.add(normalizedImage);
                        images.push({
                            source: image,
                            resourcePath: `skins/${legacySkinId}/${normalizedImage}`,
                            fileName: path.basename(normalizedImage),
                            contentType
                        });
                    }
                }

                result.skins.push({
                    legacySkinId,
                    name: typeof config.name === "string" && config.name.trim()
                        ? config.name.trim()
                        : legacySkinId,
                    frames,
                    images
                });
            } catch (error) {
                result.errors.push(`${legacySkinId}: ${error.message || String(error)}`);
            }
        }
        return JSON.stringify(result);
    }

    function archiveLegacySkins(skinsDir) {
        if (!fs.existsSync(skinsDir)) {
            return JSON.stringify({ success: false, error: "skins folder no longer exists" });
        }
        let archivePath = `${skinsDir}_old`;
        let suffix = 2;
        while (fs.existsSync(archivePath)) {
            archivePath = `${skinsDir}_old_${suffix}`;
            suffix += 1;
        }
        try {
            fs.renameSync(skinsDir, archivePath);
            return JSON.stringify({ success: true, path: archivePath });
        } catch (error) {
            return JSON.stringify({ success: false, error: error.message || String(error) });
        }
    }

    exports("GetLegacySkinConfigs", scanLegacySkins);
    exports("ArchiveLegacySkins", archiveLegacySkins);
})();
