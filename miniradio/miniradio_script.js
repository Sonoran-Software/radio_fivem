let activeChannels = [];
var maxColumns = 3; // Set your max columns here (example: 3)
let hiddenChannels = 0; // Counter to track channels not displayed

function postFrameState() {
	const hudDiv = document.getElementById("hudDiv");
	if (!hudDiv) return;

	const visible = hudDiv.style.display !== "none";
	const rect = visible ? hudDiv.getBoundingClientRect() : null;
	sendToParent({
		sonoranradioFrameControl: true,
		frame: "miniradio",
		visible,
		bounds: rect
			? {
				top: rect.top,
				left: rect.left,
				width: rect.width,
				height: rect.height,
			}
			: null,
	});
}

function setHeaderStats() {
	const channelCountEl = document.getElementById("hudChannelCount");
	const userCountEl = document.getElementById("hudUserCount");
	const totalUsers = activeChannels.reduce((count, channel) => count + channel.activeUsers.length, 0);

	channelCountEl.textContent = String(activeChannels.length);
	userCountEl.textContent = String(totalUsers);
}

function createChannelContent(channelTitle, users) {
	const channelContent = document.createElement("div");
	channelContent.classList.add("channelCard");

	const channelHeader = document.createElement("div");
	channelHeader.classList.add("channelCardHeader");

	const channelTitleWrap = document.createElement("div");
	channelTitleWrap.classList.add("channelTitleWrap");

	const channelTitleElem = document.createElement("div");
	channelTitleElem.classList.add("channelTitle");
	channelTitleElem.textContent = channelTitle;

	const channelUsersLabel = document.createElement("div");
	channelUsersLabel.classList.add("channelMeta");
	channelUsersLabel.textContent = `${users.length} active user${users.length === 1 ? "" : "s"}`;

	const channelBadge = document.createElement("div");
	channelBadge.classList.add("channelBadge");
	channelBadge.textContent = `Users ${users.length}`;

	channelTitleWrap.appendChild(channelTitleElem);
	channelTitleWrap.appendChild(channelUsersLabel);
	channelHeader.appendChild(channelTitleWrap);
	channelHeader.appendChild(channelBadge);

	const userList = document.createElement("div");
	userList.classList.add("connectedUserList");

	users.forEach((user) => {
		const userItem = document.createElement("div");
		userItem.classList.add("userItem");
		userItem.title = user.name;

		const userDot = document.createElement("span");
		userDot.classList.add("userDot");
		if (user.isTalking)
			userDot.classList.add("talking");

		const userName = document.createElement("span");
		userName.classList.add("userName");
		userName.textContent = user.name;

		userItem.appendChild(userDot);
		userItem.appendChild(userName);
		userList.appendChild(userItem);
	});

	channelContent.appendChild(channelHeader);
	channelContent.appendChild(userList);
	document.getElementById("hudContentWrapper").appendChild(channelContent);
}

function refreshCall() {
	const hudContentWrapper = document.getElementById("hudContentWrapper");
	hudContentWrapper.innerHTML = "";
	setHeaderStats();

	if (activeChannels.length == 0) {
		hudContentWrapper.innerHTML = `
			<div class="emptyState">
				<div class="emptyCard">
					<div class="emptyTitle">No Active Channels</div>
					<div class="emptyBody">You are not connected to Sonoran Radio.</div>
				</div>
			</div>
		`;
		return;
	}

	activeChannels.forEach((channel) => {
		createChannelContent(channel.channelName, channel.activeUsers);
	});
}

function moduleVisible(module, visible) {
	if (visible) {
		$("#" + module + "Div").show();
	} else {
		$("#" + module + "Div").hide();
	}
	postFrameState();
	$.post("https://sonoranradio/VisibleEvent", JSON.stringify({ state: visible, module: module }));
}

function forwardKey(type, event) {
	sendToParent({
		type,
		key: event.which,
		code: event.code,
		repeat: !!event.repeat,
		ctrlKey: !!event.ctrlKey,
	});
}

function requestEscape() {
	sendToParent({ type: "keyup", code: "Escape", key: 27, which: 27 });
	moduleVisible("hud", false);
}

$(function () {
	window.addEventListener("message", function (event) {
		if (event.data.type == "display") {
			moduleVisible(event.data.module, event.data.enabled);
		} else if (event.data.type == "config") {
			switch (event.data.key) {
				case "maxrows":
					maxrows = event.data.value;
					refreshCall();
					break;
				default:
					console.log("Invalid Config Option");
					break;
			}
		} else if (event.data.type == "channelSync") {
			activeChannels = [];
			activeChannels = event.data.channels;
			refreshCall();
		} else if (event.data.type == "resize") {
			if (event.data.module == "hud") {
				let { newWidth, newHeight } = event.data;
				newWidth = Math.min(newWidth, window.innerWidth / 1.1);
				newHeight = Math.min(newHeight, window.innerHeight / 1.1);

				const frame = document.getElementById("hudFrame");
				const div = document.getElementById("hudDiv");
				div.style.width = newWidth + "px";
				div.style.height = newHeight + "px";
				frame.style.width = "100%";
				frame.style.height = "100%";

				let left = div.offsetLeft;
				let top = div.offsetTop;
				left = Math.max(0, Math.min(left, window.innerWidth - newWidth));
				top = Math.max(0, Math.min(top, window.innerHeight - newHeight));
				div.style.left = left + "px";
				div.style.top = top + "px";
				postFrameState();
			}
		} else if (event.data.type == "setMiniRadioUIPosition") {
			let x = event.data.x;
			let y = event.data.y;
			document.getElementById("hudDiv").style.left = x;
			document.getElementById("hudDiv").style.top = y;
			postFrameState();
		}
	});

	window.addEventListener("keydown", function (event) {
		forwardKey("keydown", event);
	});
	window.addEventListener("keyup", function (event) {
		forwardKey("keyup", event);
	});
	dragElement(document.getElementById("hudDiv"), "hudHeader");
	window.addEventListener("resize", postFrameState);
	postFrameState();
	refreshCall();
});

function sendToParent(data) {
	if (parent) parent.postMessage(data, "*");
}

function dragElement(elmnt, dragHandleId) {
	var pos1 = 0,
		pos2 = 0,
		pos3 = 0,
		pos4 = 0;

	const dragHandle = document.getElementById(dragHandleId);

	if (dragHandle) {
		dragHandle.onmousedown = dragMouseDown;
	}

	function dragMouseDown(e) {
		e = e || window.event;
		if (e.target && e.target.closest("#hudHeaderControls")) return;
		e.preventDefault();
		pos3 = e.clientX;
		pos4 = e.clientY;
		document.onmouseup = closeDragElement;
		document.onmousemove = elementDrag;
	}

	function elementDrag(e) {
		e = e || window.event;
		e.preventDefault();
		pos1 = pos3 - e.clientX;
		pos2 = pos4 - e.clientY;
		pos3 = e.clientX;
		pos4 = e.clientY;

		var newTop = elmnt.offsetTop - pos2;
		var newLeft = elmnt.offsetLeft - pos1;
		newTop = Math.max(0, Math.min(newTop, window.innerHeight - elmnt.offsetHeight));
		newLeft = Math.max(0, Math.min(newLeft, window.innerWidth - elmnt.offsetWidth));
		elmnt.style.top = newTop + "px";
		elmnt.style.left = newLeft + "px";
		postFrameState();
	}

	function closeDragElement() {
		document.onmouseup = null;
		document.onmousemove = null;
		postFrameState();
		$.post("https://sonoranradio/SaveMiniRadioPos", JSON.stringify({ x: elmnt.style.left, y: elmnt.style.top }));
	}
}

window.addEventListener("message", function (event) {
	if (event.data.type == "update_connected_users") {
		$.post(
			"https://sonoranradio/UpdateConnectedUsers",
			JSON.stringify({
				users: event.data.users,
			})
		);
	}
});
