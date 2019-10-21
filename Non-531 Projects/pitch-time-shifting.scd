
b = Buffer.readChannel(s, "sample.wav".resolveRelative, channels: 0);


/* -------------- Pitch & Time Shifting --------------- */
// k * rate (and pitch) = 1/k * time of file
(
SynthDef(\playTimeShift,{ arg out = 0, bufnum;
	var signal;
	signal = PlayBuf.ar(1, bufnum, MouseY.kr(0, 0.5), loop:1);
	Out.ar(out, signal ! 2)
}).add
)
x = Synth(\playTimeShift, [\bufnum, b.bufnum])


/* -------------- Pitch Shifting Only --------------- */
(
SynthDef(\playPitchShift,{ arg out = 0, bufnum;
	var signal;
	signal = PlayBuf.ar(1, bufnum, 1, loop:1);
	signal = PitchShift.ar(
		signal,	            // stereo audio input
		0.1, 			    // grain size
		MouseY.kr(0, 0.5),	// mouse y controls pitch shift ratio
		0, 				    // pitch dispersion
		0.001			    // time dispersion
	);
	Out.ar(out, signal ! 2)
}).add
)

x = Synth(\playPitchShift, [\bufnum, b.bufnum])