let activeChannels = [];
let displayedChannels = 0; // Counter to keep track of displayed channels
var maxColumns = 3; // Set your max columns here (example: 3)
let hiddenChannels = 0; // Counter to track channels not displayed

function truncateString(string, maxLength = 15) {
	if (string.length > maxLength) {
		return string.slice(0, maxLength) + "...";
	}
	return string;
}

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
		userItem.textContent = `• ${truncateString(user.name)}`;
		userItem.title = user.name;
		userItem.style.fontSize = "12px";
		userItem.style.display = "block"; // Ensures users are stacked vertically
		userItem.style.textAlign = "left"; // Aligns user names to the left
		userList.appendChild(userItem);
	});

	// Append title, label, and user list to the main channelContent div
	channelContent.appendChild(channelTitleElem);
	channelContent.appendChild(channelUsersLabel);
	channelContent.appendChild(userList);

	// Append the channelContent to the hudContentWrapper
	document.getElementById("hudContentWrapper").appendChild(channelContent);

	// Increment the number of displayed channels
	displayedChannels++;
}

function refreshCall() {
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
					console.log("Rows set to " + event.data.value);
					refreshCall();
					break;
				default:
					console.log("Invalid Config Option");
					break;
			}
		} else if (event.data.type == "channelSync") {
			console.log("User Sync Event", JSON.stringify(event.data));
			activeChannels = [];
			activeChannels = event.data.channels;
			refreshCall();
		} else if (event.data.type == "resize") {
			if (event.data.module == "hud") {
				document.getElementById("hudFrame").width = event.data.newWidth;
				document.getElementById("hudFrame").height = event.data.newHeight;
				document.getElementById("hudDiv").style.width = event.data.newWidth;
				document.getElementById("hudDiv").style.height = event.data.newHeight;
			}
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
