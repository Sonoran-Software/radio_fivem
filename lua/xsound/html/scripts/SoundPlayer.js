class SoundPlayer {
	static yPlayer = null;
	constructor() {
		this.url = "test";
		this.name = "";
		this.dynamic = false;
		this.distance = 10;
		this.volume = 1.0;
		this.pos = [0.0, 0.0, 0.0];
		this.max_volume = -1.0;
		this.div_id = "myAudio_" + Math.floor(Math.random() * 9999999);
		this.loop = false;
		this.load = false;
		this.isMuted_ = false;
		this.audioPlayer = null;
	}
	getDistance() {
		return this.distance;
	}
	getLocation() {
		return this.pos;
	}
	getVolume() {
		return this.volume;
	}
	getMaxVolume() {
		return this.max_volume;
	}
	getUrlSound() {
		return this.url;
	}
	isDynamic() {
		return this.dynamic;
	}
	getDivId() {
		return this.div_id;
	}
	isLoop() {
		return this.loop;
	}
	getName() {
		return this.name;
	}
	loaded() {
		return this.load;
	}

	getAudioPlayer() {
		return this.audioPlayer;
	}
	setLoaded(result) {
		this.load = result;
	}
	setName(result) {
		this.name = result;
	}
	setDistance(result) {
		this.distance = result;
	}
	setDynamic(result) {
		this.dynamic = result;
	}
	setLocation(x_, y_, z_) {
		this.pos = [x_, y_, z_];
	}

	setSoundUrl(result) {
		this.url = result.replace(/<[^>]*>?/gm, "");
	}

	setLoop(result) {
		if (this.audioPlayer != null) {
			this.audioPlayer.loop(result);
		}
		this.loop = result;
	}

	setMaxVolume(result) {
		this.max_volume = result;
	}
	setVolume(result) {
		this.volume = result;
		if (this.max_volume == -1) this.max_volume = result;
		if (this.max_volume > this.volume - 0.01) this.volume = this.max_volume;
		if (this.dynamic && (this.isMuted_ || isMutedAll)) {
			if (this.audioPlayer != null) {
				this.audioPlayer.volume(0);
			}
		} else {
			if (this.audioPlayer != null) {
				this.audioPlayer.volume(result);
			}
		}
	}

	create() {
		$.post(
			"https://sonoranradio/events-xsound",
			JSON.stringify({
				type: "onLoading",
				id: this.getName(),
			})
		);
		var link = this.getUrlSound();
		this.audioPlayer = new Howl({
			src: [link],
			loop: false,
			html5: true,
			autoplay: false,
			volume: 0.0,
			onend: function (event) {
				ended(null);
			},
			onplay: function () {
				isReady("nothing", true);
			},
		});
		$("#" + this.div_id).remove();
		$("body").append("<div id = '" + this.div_id + "' style='display:none'>" + this.getUrlSound() + "</div>");
	}
	delete() {
		if (this.audioPlayer != null) {
			this.audioPlayer.pause();
			this.audioPlayer.stop();
			this.audioPlayer.unload();
		}
		this.audioPlayer = null;
		$("#" + this.div_id).remove();
	}

	updateVolume(distance, maxDistance) {
		var d_max = maxDistance;

		// Calculate the 3D distance between the player and the speaker
		var distance = distance
		var vol = 0;
		if (distance < d_max) {
			// Normalize the distance to a percentage of maxDistance
			var normalizedDistance = distance / d_max;
			var proximity = 1 - normalizedDistance; // Closer means higher proximity

			// Adjust volume based on proximity (closer = louder)
			vol = 1 * proximity;
			this.setVolume(vol);
			this.isMuted_ = false;
		} else {
			// If the player is out of range, mute the sound
			this.setVolume(0);
			this.isMuted_ = true;
		}
	}

	updatePan(playerPos, speakerPos, playerHeading) {
		// Calculate the angle to determine if the sound is left, right, or center
		var angle = Math.atan2(speakerPos.y - playerPos.y, speakerPos.x - playerPos.x);

		// Normalize the angle based on player heading
		var relativeAngle = angle - playerHeading;

		// Convert to stereo pan (-1 = left, 1 = right)
		var pan = Math.sin(relativeAngle);

		this.audioPlayer.stereo(pan);
	}

	updateSound(playerPos, speakerPos, playerHeading, maxDistance, distance) {
		// Update the volume based on distance
		this.updateVolume(distance, maxDistance);

		// Update the stereo panning based on heading
		this.updatePan(playerPos, speakerPos, playerHeading);
	}

	play() {
		if (this.audioPlayer != null) {
			this.audioPlayer.play();
		}
	}
	pause() {
		if (this.audioPlayer != null) this.audioPlayer.pause();
	}

	resume() {
		if (this.audioPlayer != null) this.audioPlayer.play();
	}

	isMuted() {
		return this.isMuted_;
	}

	mute() {
		this.isMuted_ = true;
		this.setVolume(0);
	}

	unmute() {
		this.isMuted_ = false;
		this.setVolume(this.getVolume());
	}

	unmuteSilent() {
		this.isMuted_ = false;
	}

	setTimeStamp(time) {
		this.audioPlayer.seek(time);
	}

	isPlaying() {
		return this.audioPlayer != null && this.audioPlayer.playing();
	}
}
