function showBody(toggle) {
    console.log("Body Shown: " + toggle);
    if (toggle) document.body.classList.remove("hidden");
    else document.body.classList.add("hidden");
}

function togglePower() {
    document.getElementById('radio-content').hidden = !document.getElementById('radio-content').hidden
}

(() => {
    const socket = new WebSocket("ws://lh.bestdev.pw:33802");
    socket.onopen = (e) => {
        console.log("websocket open");
    };
    socket.onmessage = (e) => {
        console.log(JSON.parse(e.data));
    };
    socket.onerror = function (err) {
        console.error(err.message);
    };

    document.querySelector("#freq_submit").onclick = () => {
        const freqMaj = Number.parseInt(
            document.querySelector("#freq_major").value
        );
        const freqMin = Number.parseInt(
            document.querySelector("#freq_minor").value
        );
        socket.send(
            JSON.stringify({
                type: "SET_TALK_GROUP_FREQ",
                freq_maj: freqMaj,
                freq_min: freqMin,
            })
        );
    };

    async function postClient(data, route = "/data") {
        const url = new URL(route, `http://${GetParentResourceName()}`);
        const res = await fetch(url.toString(), {
            method: "POST",
            body: JSON.stringify(data),
        });
        if (res.status !== 200)
            return console.error(`failed request with code: ${res.status}`);

        const msg = await res.json();
        if (msg !== "OK") console.error(`failed request with message: ${msg}`);
    }

    function showBody(toggle) {
        console.log(toggle);
        if (toggle) document.body.classList.remove("hidden");
        else document.body.classList.add("hidden");
    }

    window.addEventListener("message", ({ data }) => {
        if (data.type === "show") showBody(true);
        else if (data.type === "hide") showBody(false);
        else if (data.type === "update_position")
            socket.send(
                JSON.stringify({
                    type: "UPDATE_POSITION",
                    to_cid: 1,
                    position: data.position,
                })
            );
    });
    window.addEventListener("keydown", (e) => {
        if (e.key.toLowerCase() === "escape") postClient({ type: "hide" });
    });
})();
