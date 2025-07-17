let activeChannels = [];
var maxColumns = 3; // Set your max columns here (example: 3)
let hiddenChannels = 0; // Counter to track channels not displayed

// Function to create a new HUD content block for each channel
function createChannelContent(channelTitle, users) {
	// Create the main div for the channel
	const channelContent = document.createElement("div");
	channelContent.classList.add("channelContent"); // Add class for styling

	// Create the channel title element
	const channelTitleElem = document.createElement("span");
	channelTitleElem.textContent = channelTitle;
	channelTitleElem.style.fontSize = "14px";

	// Create the connected users label
	const channelUsersLabel = document.createElement("span");
	channelUsersLabel.textContent = `Users: ${users.length}`;
	channelUsersLabel.style.fontSize = "12px";

	// Create the connected users list container
	const userList = document.createElement("div");
	userList.id = "connectedUserList";

	// Loop through each user and create a span for each, stacked vertically
	users.forEach((user) => {
		const userItem = document.createElement("span");
		userItem.classList.add("userItem"); // Add class for tooltip and styling
		userItem.textContent = `• ${user.name}`;
		userItem.title = user.name;
		userItem.style.fontSize = "12px";
		userItem.style.display = "block"; // Ensures users are stacked vertically
		userItem.style.textAlign = "left"; // Aligns user names to the left
		if (user.isTalking) {
			userItem.style.color = "green";
		} else {
			userItem.style.color = "white";
		}
		const tooltipText = document.createElement("span");
		tooltipText.classList.add("tooltiptext");
		tooltipText.textContent = user.name; // Full name displayed in tooltip

		// Append the tooltip text to the user item
		userItem.appendChild(tooltipText);
		userList.appendChild(userItem);
	});

	// Append title, label, and user list to the main channelContent div
	channelContent.appendChild(channelTitleElem);
	channelContent.appendChild(channelUsersLabel);
	channelContent.appendChild(userList);

	// Append the channelContent to the hudContentWrapper
	document.getElementById("hudContentWrapper").appendChild(channelContent);
}

function refreshCall() {
	const hudContentWrapper = document.getElementById("hudContentWrapper");
	hudContentWrapper.innerHTML = "";
	if (activeChannels.length == 0) {
		const channelContent = document.createElement("div");
		channelContent.classList.add("channelContent"); // Add class for styling
		// Create the channel title element
		const channelTitleElem = document.createElement("span");
		channelTitleElem.textContent = "No Active Channels";
		channelTitleElem.style.fontSize = "14px";

		// Create the connected users label
		const channelUsersLabel = document.createElement("span");
		channelUsersLabel.textContent = `You are not connected to Sonoran Radio`;
		channelUsersLabel.style.fontSize = "12px";
		channelContent.appendChild(channelTitleElem);
		channelContent.appendChild(channelUsersLabel);
		// Append the channelContent to the hudContentWrapper
		document.getElementById("hudContentWrapper").appendChild(channelContent);
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
	$.post("https://sonoranradio/VisibleEvent", JSON.stringify({ state: visible, module: module }));
}

function showHelp() {
	$.post("https://sonoranradio/ShowHelp");
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
				newWidth = Math.min(newWidth, window.innerWidth / 1.1); // Ensure minimum width
				newHeight = Math.min(newHeight, window.innerHeight / 1.1); // Ensure minimum height

				// update frame and div dimensions
				const frame = document.getElementById("hudFrame");
				const div = document.getElementById("hudDiv");
				frame.width = newWidth;
				frame.height = newHeight;
				div.style.width = newWidth + "px";
				div.style.height = newHeight + "px";
				// clamp position so it doesn't exceed window bounds
				let left = div.offsetLeft;
				let top = div.offsetTop;
				left = Math.max(0, Math.min(left, window.innerWidth - newWidth));
				top = Math.max(0, Math.min(top, window.innerHeight - newHeight));
				div.style.left = left + "px";
				div.style.top = top + "px";
				frame.style.left = left + "px";
				frame.style.top = top + "px";
			}
		} else if (event.data.type == "setMiniRadioUIPosition") {
			let x = event.data.x;
			let y = event.data.y;
			document.getElementById("hudDiv").style.left = x;
			document.getElementById("hudDiv").style.top = y;
			document.getElementById("hudFrame").style.left = x;
			document.getElementById("hudFrame").style.top = y;
		}

	});
	document.onkeyup = function (data) {
		sendToParent({ type: "keyup", key: data.which, code: data.code });
	};
	dragElement(document.getElementById("hudDiv"), "hudHeader");
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
		// calculate and clamp new position to keep within window boundaries
		var newTop = elmnt.offsetTop - pos2;
		var newLeft = elmnt.offsetLeft - pos1;
		newTop = Math.max(0, Math.min(newTop, window.innerHeight - elmnt.offsetHeight));
		newLeft = Math.max(0, Math.min(newLeft, window.innerWidth - elmnt.offsetWidth));
		elmnt.style.top = newTop + "px";
		elmnt.style.left = newLeft + "px";
	}

	function closeDragElement() {
		// stop moving when mouse button is released
		document.onmouseup = null;
		document.onmousemove = null;
		// save position
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
