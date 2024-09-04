var activeChannel = [(channelName = ""), (activeUsers = [])];

function setupHud() {
	$("#hudHeaderTime")[0].innerText = "SonoranRadio Mini";
}

function refreshCall() {
	setupHud();

	let activeChannel = true;

	if (activeChannel.channelName === "") activeChannel = false;
	if (!activeChannel) {
		$("#callCode")[0].innerText = "You are not currently connected to a channel.";
		$("#callTitle")[0].innerText = "There are no active users on this channel.";
		$("#callLocation")[0].innerText = "";
		$("#callDescription")[0].innerText = "";
		$("#callNotes")[0].innerHTML = "";
		$("#callUnits")[0].innerHTML = "";
		$("#hudDetails")[0].style.display = "none";
	} else {
		$("#callCode")[0].innerText = activeChannel.channelName;
		$("#callTitle")[0].innerText = "Connected User:";
		$("#callNotes")[0].innerHTML = "";
		if (activeChannel.activeUsers.length > 0) {
			if (activeChannel.activeUsers.length > maxrows) {
				$("#callNotes")[0].innerHTML +=
					'<span class="callnote">** NOTE: ' + (activeChannel.activeUsers.length - maxrows) + " users hidden. (Use /miniradiorows) ***</span>";
			}
			for (var i = activeChannel.activeUsers.length - 1 > maxrows ? maxrows : activeChannel.activeUsers.length - 1; i >= 0; i--) {
				let callnote = activeChannel.activeUsers[i].name;
				$("#callNotes")[0].innerHTML += '<span class="callnote">' + callnote + "</span>";
			}
		}
	}
}

function moduleVisible(module, visible) {
	if (visible) {
		$("#" + module + "Div").show();
	} else {
		$("#" + module + "Div").hide();
	}
	$.post("https://sonoranradio/VisibleEvent", JSON.stringify({ state: visible, module: module }));
}

function showHelp() {
	$.post("https://sonoranradio/ShowHelp");
}

$(function () {
	window.addEventListener("message", function (event) {
		if (event.data.type == "display") {
			moduleVisible(event.data.module, event.data.enabled);
			setHotkeys(event.data.keyMap);
		} else if (event.data.type == "config") {
			switch (event.data.key) {
				case "maxrows":
					maxrows = event.data.value;
					console.log("Rows set to " + event.data.value);
					refreshCall();
					break;
				default:
					console.log("Invalid Config Option");
					break;
			}
		} else if (event.data.type == "userSync") {
			ActiveChannel.activeUsers = event.data.activeUsers;
			refreshCall();
		}
	});
	document.onkeyup = function (data) {
		switch (data.which) {
			case 27:
				$.post("https://sonoranradio/NUIFocusOff", JSON.stringify({}));
				break;
			default:
				break;
		}
	};
	dragElement(document.getElementById("hudDiv"));
});

function dragElement(elmnt) {
	var pos1 = 0,
		pos2 = 0,
		pos3 = 0,
		pos4 = 0;
	if (document.getElementById(elmnt.id + "header")) {
		// if present, the header is where you move the DIV from:
		document.getElementById(elmnt.id + "header").onmousedown = dragMouseDown;
	} else {
		// otherwise, move the DIV from anywhere inside the DIV:
		elmnt.onmousedown = dragMouseDown;
	}

	function dragMouseDown(e) {
		e = e || window.event;
		e.preventDefault();
		// get the mouse cursor position at startup:
		pos3 = e.clientX;
		pos4 = e.clientY;
		document.onmouseup = closeDragElement;
		// call a function whenever the cursor moves:
		document.onmousemove = elementDrag;
	}

	function elementDrag(e) {
		e = e || window.event;
		e.preventDefault();
		// calculate the new cursor position:
		pos1 = pos3 - e.clientX;
		pos2 = pos4 - e.clientY;
		pos3 = e.clientX;
		pos4 = e.clientY;
		// set the element's new position:
		elmnt.style.top = elmnt.offsetTop - pos2 + "px";
		elmnt.style.left = elmnt.offsetLeft - pos1 + "px";
	}

	function closeDragElement() {
		// stop moving when mouse button is released:
		document.onmouseup = null;
		document.onmousemove = null;
	}
}
