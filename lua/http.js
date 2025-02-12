exports('HandleHttpRequest', (dest, callback, method, data, headers) => {
    emit("SonoranRadio::core:writeLog", "debug", "[http] to: " + dest + " - data: " + dest, JSON.stringify(data));
    const destInfo = new URL(dest);
    const options = {
        hostname: destInfo.hostname,
        path: destInfo.pathname,
        port: destInfo.port,
        method: method,
        headers: headers != null && typeof headers == 'object' && !Array.isArray(headers) ? headers : {}
    };
    options.headers['X-SonoranRadio-Version'] = GetResourceMetadata(GetCurrentResourceName(), "version", 0)

    if (method === "POST") {
        options.headers['Content-Type'] = 'application/json'
    } else if (method !== "GET") {
        console.error("Invalid request. Only GET/POST supported. Method: " + method);
        return callback(500, "", {});
    }

    const client = destInfo.protocol === 'http:' ? require('http') : require('https');
    const req = client.request(options);
    req.on('response', (res) => {
        res.setEncoding('utf-8');

        let output = "";
        res.on('data', (d) => {
            output += d.toString()
        });
        res.on('end', () => {
            callback(res.statusCode, output, res.headers);
        });
    });
    req.on('error', (error) => {
        let ignore_ids = ["EAI_AGAIN", "ETIMEOUT", "ENOTFOUND"]
        if (!ignore_ids.includes(error.code))
            console.debug("HTTP error caught: " + JSON.stringify(error));
        callback(error.errono, {}, {});
    })
    if (method == "POST") {
        req.write(data);
    }
    req.end();
});
