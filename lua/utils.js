(() => {
    const fs = require("fs");

    exports('HandleHttpRequest', (dest, callback, method, data, headers) => {
        emit("SonoranRadio::core:writeLog", "debug", "[http] to: " + dest + " - data: " + dest, JSON.stringify(data));
        const destInfo = new URL(dest);
        const options = {
            hostname: destInfo.hostname,
            path: destInfo.pathname,
            port: destInfo.port,
            method: method,
            headers: headers != null && typeof headers == 'object' && !Array.isArray(headers) ? headers : {},
        };
        options.headers['X-User-Agent'] = 'Sonoran Radio FiveM Resource'
        options.headers['X-SonoranRadio-Version'] = GetResourceMetadata(GetCurrentResourceName(), "version", 0)

        if (method === "POST" && !options.headers['Content-Type'])
            options.headers['Content-Type'] = 'application/json'
        if (method !== "GET" && method !== 'POST') {
            console.error("Invalid request. Only GET/POST supported. Method: " + method);
            if (callback) callback(-1, "", {});
            return void (callback = undefined);
        }

        const client = destInfo.protocol === 'http:' ? require('http') : require('https');
        const req = client.request(options, (res) => {
            res.setEncoding('utf-8');

            let output = "";
            res.on('data', (chunk) => {
                output += chunk.toString()
            });
            res.on('end', () => {
                if (callback) callback(res.statusCode, output, res.headers);
                callback = undefined;
            });
        });
        req.on('error', (error) => {
            if (callback) callback(-1, error, {});
            callback = undefined;
        })
        if (method == "POST") {
            req.write(data);
        }
        req.end();

        setTimeout(() => {
            if (callback) callback(-1, {}, {});
            callback = undefined;
        }, 30000);
    });

    // Synchronously read only top‑level directories under skins/
    function getAvailableFrames(skinsDir) {
        return fs
            .readdirSync(skinsDir, { withFileTypes: true })
            .filter((dirent) => dirent.isDirectory())
            .map((dirent) => dirent.name);
    }
    exports("GetAvailableFrames", getAvailableFrames);
})();
