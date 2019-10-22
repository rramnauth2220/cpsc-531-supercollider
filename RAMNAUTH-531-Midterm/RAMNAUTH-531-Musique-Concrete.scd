/*
    Rebecca Ramnauth - Musique Concrète - CPSC 531
*/

(
s.waitForBoot {

	/* ---------------  INPUTS  --------------- */
	~metronome_voice = true;    ~metronome_amp = 0.25;    // rhythm
	~vocal_voice = true;        ~vocal_amp = 0.25;        // main "vocals"
	~melody_voice = true;       ~melody_amp = 0.25;       // repeating "melody"
	~ambient_voice = false;      ~ambient_amp = 0.75;      // ambient speech + background

	~measures = inf; // # of measures
	~rate = 0.3; // audio rate

	~input = "samples/midi/chopin_nocturne.mid"; // patterns derived from given midi file
	~patternLength = 50; // how much data to take from midi input
	~chainLength = 500; // resulting chain length
	~chainOrder = 2; // order of Markov Chain

	/* ---------------  SYNTH DEFINITIONS  --------------- */

	SynthDef(\playBuf,
		{ | buffer, start = 0, dur = 0.25, amp = 1 |
			var sig = PlayBuf.ar(1, buffer, rate: ~rate, startPos: start, loop: 1);
			var env = EnvGen.kr(Env.linen(0.01, dur, 0.01, level:amp), doneAction:2);
			OffsetOut.ar(0, Pan2.ar(sig * env !2));
	}).add;

	SynthDef(\drone, { | out = 0, speed = 1, amp = 0.5, rel = 0.5, dur = 1, freq=200 |
		var base = LFNoise1;
		var adsr = EnvGen.ar(Env.linen(dur * 1, rel, 0.1, 1, -3), doneAction: 2);
		var sig = HPF.ar(FreeVerb2.ar(*XFade2.ar(SinOscFB.ar([20, freq],base.ar(speed * 2) + 1 / 8),
			SinOscFB.ar([freq, 25],base.ar(speed) + 1 / 2),base.ar(20))), 120);
		sig = HPF.ar(sig, 100);
		sig = GVerb.ar(sig);
		sig = (sig * adsr);
		Out.ar(out, sig * amp);
	}).add;

	SynthDef(\bass, { | out = 0, amp = 1, b = 2, rel = 15, freq = 440 |
		var bass, s1, f, lag, d;
		var env = EnvGen.ar(Env.linen(0.0, rel, 0), doneAction: 2);
		d = Duty.kr(b * 4, 0, Dseq([b, b * 2, b * 4, b / 2],inf));
		lag = Duty.kr(b * 4, 0, Dseq([0.2, 0.1, 0.08, 0.02, 0.052, 0.12],inf)).lag(0.2);
		s1 = SinOsc.ar(Lag.kr([freq, freq]), mul: 0.2) * Decay2.kr(Impulse.kr([b / 16, b / 8]), 0.4,decayTime: b * 4);
		s1 = FreeVerb.ar(s1, room: 2, mul: 0.5, add: s1);
		Out.ar(out,(s1 * amp) * env);
	}).add;

	// not used, but next steps: auto synth selection based on inputs
	SynthDef(\piano, { | out=0, freq=440, amp=0.1, gate=1 |
		var son = MdaPiano.ar(freq, gate, release: 0.9, stereo: 0.3, sustain: 0.5);
		DetectSilence.ar(son, 0.01, doneAction:2);
		Out.ar(out, son * amp);
	}).add;

	/* ---------------  Helper Functions  --------------- */

	// returns index of @element in @pattern
	~getIndex = { | element, pattern |
		var index = 0;
		while ( { (pattern[index] != element)
			&& (index < pattern.size) },
		{ index = index + 1; });
		if (index >= pattern.size, -1, index);
	}; // ~getIndex.value(\c, ~inBeats).postln; // test case

	// returns distances of each element in @beats relative to indices in @pattern
	~getDistance = { | beats, pattern |
		var distanceArr = [];
		var prevIndex = 0;
		for (0, beats.size - 1, { |i|
			var currIndex = ~getIndex.value(beats[i], pattern);
			var distance = currIndex - prevIndex;
			distanceArr = distanceArr.add(distance);
			prevIndex = currIndex; }
		);
		distanceArr;
	}; // ~getDistance.value(~inBeats, ~p).postln; // test case

	// returns array of frequencies of elements of @set in @arr
	~getFrequencies = { | arr, set |
		var histogram = [];
		var set_index = 0; var arr_index = 0; k = 0;
		for (0, set.size, {
			arg i;
			for (0, arr.size, {
				arg j;
				if (arr[j] == set[i]) { k = k + 1; }
			});
			histogram = histogram.add(k);
			k = 0;
		});
		histogram;
	}; // ~getFrequencies.value([3, 2, 5, 1, 1, 1], [3, 2, 5, 1]).postln; // test case

	// returns @size most common elements in @set according to @freq
	~getNCommon = { | freq, set, size |
		var arr = [];
		for (0, size - 1, {
			arg j;
			var index = 0;
			var largest_frequency = freq[0];
			var largest_value = set[0];
			for (1, set.size, {
				arg i;
				if ((freq[i] != -1) && (freq[i] > largest_frequency)) {
					largest_frequency = freq[i];
					largest_value = set[i];
					index = i;
				}
			});
			arr = arr.add(largest_value);
			freq.put(index, -1);
			set.put(index, -1);
		});
		arr;
	}; // ~getNCommon.value(~getFrequencies.value([3, 2, 5, 1, 3, 1], [3, 2, 5, 1]), [3, 2, 5, 1], 2) // test case

	// returns sample standard deviation of elements in @arr
	~calculateSD = { | arr |
		var sum = 0;
		var mean;
		var standardDeviation = 0;
		for (arr.size - 1, 0, {arg j; if (arr[j].isNil || (arr[j].isNumber == false)) { arr.removeAt(j); } });
		for (0, arr.size - 1, { arg i; sum = sum + arr[i]; });
		mean = sum/arr.size;
		for (0, arr.size - 1, { arg i; standardDeviation = standardDeviation + ((arr[i] - mean) ** 2); });
		(standardDeviation/arr.size).sqrt;
	}; // ~calculateSD.value([0, 4, 1, 5, 2].asArray); // test case

	/* ---------------  Transformation Methods  --------------- */

	// reverse beat sequence @seq
	~backwards = { |seq| seq.reverse };

	// inverts @seq using relative steps found in @pattern
	~invert = { |seq, pattern|
		var invertArr = [];
		var distances = ~getDistance.value(seq, pattern) * -1;
		var origin = 0;
		for (0, seq.size - 1) { |i|
			origin = distances[i] + origin; // recalc index from steps
			invertArr = invertArr.add(pattern.wrapAt(origin));
		};
		invertArr;
	}; // ~invert.value(~inBeats, ~pattern).postln; // test case

	// inverts @seq, then reverses resulting sequence
	~invertBackward = { |seq, pattern| ~backwards.value(~invert.value(seq, pattern), pattern) };
	// ~invert.value(~inBeats, ~p).postln; ~invertBackward.value(~inBeats, ~p).postln; // test case

	// randomizes the order of elements in @seq
	~shuffle = { |seq| seq.scramble };
	// ~shuffle.value(~inBeats).postln; // test case

	/* ---------------  Mapping Sound to Symbols --------------- */

	if (~metronome_voice == true) {
		var inBeats = [\a, \b, \a, \a, \c]; // beat-keeping

		var fragment_amplitudes = [
			[rrand(0, ~metronome_amp), rrand(0, ~metronome_amp)], // first fragment
			[rrand(0, ~metronome_amp), rrand(0, ~metronome_amp)], // second fragment
			[rrand(0, ~metronome_amp), rrand(0, ~metronome_amp)]  // third fragment
		];

		// macro-structure inputs
		var pattern = [\a, \a, \c, \b, \r, \r, \r, \c, \a, \r]; // originating pattern
		var transforms = [
			\reverse,
			\invert,
			\forward,
			\reverseInvert,
			\shuffle
		];

		// read metronome sound files -- next steps: abstracting out # of subjects
		var subjects = PathName.new("samples/subject/".resolveRelative).entries;

		var frag_1 = List[]; // list for fragment sound 1
		var frag_2 = List[]; // list for fragment sound 2
		var frag_3 = List[]; // list for fragment sound 3

		var outBeats = List[]; // will hold resulting beats after transformations

		// apply transforms at add to outBeats 2D array
		transforms.size.do {|i|
			if (transforms[i] == \reverse,       {outBeats.add(~backwards.value(inBeats))});
			if (transforms[i] == \invert,        {outBeats.add(~invert.value(inBeats, pattern))});
			if (transforms[i] == \forward,       {outBeats.add(inBeats)});
			if (transforms[i] == \reverseInvert, {outBeats.add(~invertBackward.value(inBeats, pattern))});
			if (transforms[i] == \shuffle,       {outBeats.add(~shuffle.value(inBeats))});
		};

		outBeats = outBeats.flatten;


		// create separate "parts" for each fragment sound
		outBeats.size.do {|i|
			if (outBeats[i] == \a,  {frag_1.add(0.25)},  {frag_1.add(Rest(0.25))});
			if (outBeats[i] == \b,  {frag_2.add(0.25)},  {frag_2.add(Rest(0.25))});
			if (outBeats[i] == \c,  {frag_3.add(0.25)},  {frag_3.add(Rest(0.25))});
		};

		b = Array.fill(3, { rrand(0, subjects.size - 1)}).collect{|val| Buffer.readChannel(s, subjects[val].asRelativePath, channels: 0) };

		s.sync;

		~subject_a = Pbind(
			\instrument, \playBuf,
			\dur,        Pseq(frag_1, ~measures),
			\buffer,     b[0],
			\amp,        Pseq(fragment_amplitudes[0], ~measures)
		);
		~subject_b = Pbind(
			\instrument, \playBuf,
			\dur,        Pseq(frag_2, ~measures),
			\buffer,     b[1],
			\amp,        Pseq(fragment_amplitudes[1], ~measures)
		);
		~subject_c = Pbind(
			\instrument, \playBuf,
			\dur,        Pseq(frag_3, ~measures),
			\buffer,     b[2],
			\amp,        Pseq(fragment_amplitudes[2], ~measures)
		);

		Ppar([~subject_a, ~subject_b, ~subject_c], ~measures).play;
	};

	if (~vocal_voice || ~melody_voice){
		f = SimpleMIDIFile.read(~input.resolveRelative);
		c = f.patternize;
		t = c.asStream;
		~elements = []; ~notes = []; ~durations = []; ~amplitudes = [];
		~patternLength.do({
			~elements = ~elements.add(t.next(Event.default));
			~notes = ~notes.add(~elements[~elements.size - 1].midinote);
			~durations = ~durations.add(~elements[~elements.size - 1].dur);
			~amplitudes = ~amplitudes.add(~elements[~elements.size - 1].amp);
		});
	};

	if (~vocal_voice == true) {
		m = MarkovSetN.fill(~chainLength, Pseq(~notes.asArray).asStream, ~chainOrder);
		m.makeSeeds;
		x = m.asStream;
		x.next([0, ~chainOrder]);
		~markov_notes = Array.fill(~notes.size, {x.next});

		s.sync;

		Pbind(\instrument, \drone,
			\freq, Pseq(~markov_notes.midicps, ~measures),
			\speed, Pseq(~durations, ~measures),
			\amp, Pseq(~amplitudes.normalize(0, ~vocal_amp), ~measures))
		.play;
	};

	if (~melody_voice == true){
		var melody_length = ~calculateSD.value(~notes).round(1);

		var note_frequencies = ~getFrequencies.value(~notes, ~notes.asSet.asArray);
		var melody_notes = ~getNCommon.value(note_frequencies, ~notes.asSet.asArray, melody_length);

		var duration_frequencies = ~getFrequencies.value(~durations, ~durations.asSet.asArray);
		var melody_durations = ~getNCommon.value(duration_frequencies, ~durations.asSet.asArray, melody_length);

		// given chance the most common amplitude is 0 -- next step, use this as a factor of amp
		//var amplitude_frequencies = ~getFrequencies.value(~amplitudes, ~amplitudes.asSet.asArray);
		//var melody_amplitudes = ~getNCommon.value(amplitude_frequencies, ~amplitudes.asSet.asArray, 1);

		s.sync;

		Pbind(\instrument, \bass,
			\freq, Pseq(melody_notes.midicps, ~measures),
			\dur, Pseq(melody_durations, ~measures),
			\amp, ~melody_amp
		).play;
	};

	if (~ambient_voice == true){
		var ambient_sounds = PathName.new("samples/ambient/sound/".resolveRelative).entries;
		var sound_input = Buffer.readChannel(s, ambient_sounds[rrand(0, ambient_sounds.size - 1)].asRelativePath, channels: 0);

		~speech = SynthDef(\speech, {| out = 0, bufnum = 0 |
			var signal, speech_input;
			var ambient_speeches = PathName.new("samples/ambient/speech/".resolveRelative).entries;
			var ambient_speech = ambient_speeches[rrand(0, ambient_speeches.size - 1)];
			speech_input = Buffer.read(s, ambient_speech.asRelativePath);
			signal = PlayBuf.ar(2, speech_input, rate: ambient_speech.fileNameWithoutExtension.asFloat, loop: 1);
			signal = PitchShift.ar(
				signal,	        // stereo audio input
				0.1, 			// grain size
				1,              // control rate
				0.01, 			// pitch dispersion
				SinOsc.ar(1)	// time dispersion
			);
			Out.ar(out, signal * ~ambient_amp
			)
		});

		s.sync;

		//{ (PlayBuf.ar(1, sound_input, rate: 0.4, loop: 1) * ~ambient_amp * 0.5).dup }.play;
		~speech.play(s, [\out, 0, \bufnum, b]);
	};
}
)