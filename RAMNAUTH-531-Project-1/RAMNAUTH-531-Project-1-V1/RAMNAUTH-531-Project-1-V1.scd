/*

                  _        _        _                _
                 | |      (_)      | |              | |
  _ __ ___   __ _| |_ _ __ ___  __ | |__   ___  __ _| |_ ___
 | '_ ` _ \ / _` | __| '__| \ \/ / | '_ \ / _ \/ _` | __/ __|
 | | | | | | (_| | |_| |  | |>  <  | |_) |  __/ (_| | |_\__ \
 |_| |_| |_|\__,_|\__|_|  |_/_/\_\ |_.__/ \___|\__,_|\__|___/

  Rebecca Ramnauth
  Adapted from matrix-based-beats.scd, by Scott Petersen
  CSPC 531, Project 1, 28 Sept. 2019

  Core deliverables with ~line numbers:
  Line 37  - Ability to preselect patterns [input beat]:
  Line 163 - Play multiple samples at once: Pattern + SynthDef
  Line 40  - Total number of measures
  Line 57  - Arrangement of patterns (transformations of) macro-structure
  Line 112 - Transformations: forward, backward, inverted, shifted, and all permutations *plus*:
  Line 112 - shuffle, pyramid, any other array transforms
  Line 39  - Time signature/pattern length control: (TempoClock.beats)
  Line 38  - Tempo control: (TempoClock.tempo)
  Line 83  - Pitch variation of samples: (rate arg in PlayBuf)

  Stretch goals achieved
  Line 85/191  - A system for generating and scheduling pan variation/control per sample
  Line 82/192  - An 'accent' layer of amplitude variation patterns, overlaid on the sequencing patterns
  Line 163-171 - Ability to generate partial measures such that "fills" made by compositing different beats
*/

(
s.waitForBoot {

/* ---------------  USER INPUTS  --------------- */

// basic beat inputs
~inBeats = [\k, \s, \h, \hH]; // underlying beat
~tempo = 1.5; // tempo
~beats = 4; // time signature
~measures = inf; // # of measures
~rate = 0.8; // audio rate
~pan = [
		0.5, // kick
		1, // snare
		-1, // hat
		0.6 // hatOpen
	]; // pan value for each sample from -1 (left) to 1 (right)
~amplitudes = [
		[0.5, 1, 0.75], // kick
		[0.3, 0.1, 1], // snare
		[0.5, 0.3, 0.1], // hat
		[0.3, 0.5, 2]  // hatOpen
	];

// macro-structure inputs
~pattern = [\k, \h, \hH, \h, \s, \h, \hH, \h]; // originating pattern
~transforms = [
		\reverse,
		\invert,
		\forward,
		\shift,
		\reverseInvert,
		\shuffle,
		\pyramid
	]; // transformation sequence on input beat sequence (~inBeats) and possible transforms
~shiftVal = 0; // shift value, if shift is a requested transform
~pyramidVal = 1; // pyramid pattern type, if pyramid is a requested transform


/* ---------------  BEAT GENERATOR  --------------- */

// set tempo
t = TempoClock.default;
t.tempo = ~tempo;
t.beats = ~beats;

// read sound files
b = [\kick, \sd, \hh, \hH].collect{|val| Buffer.read(s,(val++".wav").resolveRelative) };

// define synth
SynthDef(\playBuf,
		{ |buffer, start = 0, dur = 0.25, pan, amp = 1|
	var sig = PlayBuf.ar(1, buffer, rate: ~rate, startPos: start, loop: 0);
	var env = EnvGen.kr(Env.linen(0.01, dur, 0.01, level:amp), doneAction:2);
	OffsetOut.ar(0, Pan2.ar(sig, pan, env));
}).add;

/* ---------------  Helper Functions  --------------- */

// returns index of @element in @pattern
~getIndex = { | element, pattern |
		var index = 0;
		while ( { (pattern[index] != element)
			&& (index < pattern.size) },
			{ index = index + 1; });
		if (index >= pattern.size, -1, index);
	}; // ~getIndex.value(\h, ~inBeats).postln; // test case

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

// shifts @seq by @shiftAmt steps according to @pattern
~shift = { |shiftAmt, seq, pattern|
		var shiftArr = [];
		var distances = ~getDistance.value(seq, pattern) + shiftAmt;
		var origin = 0;
		for (0, seq.size - 1) { |i|
			origin = distances[i] + origin; // recalc index from steps
			shiftArr = shiftArr.add(pattern.wrapAt(origin));
		};
		shiftArr;
	}; // ~shift.value(2, ~inBeats, ~pattern).postln; // test case

// inverts @seq, then reverses resulting sequence
~invertBackward = { |seq, pattern| ~backwards.value(~invert.value(seq, pattern), pattern) };
// ~invert.value(~inBeats, ~p).postln; ~invertBackward.value(~inBeats, ~p).postln; // test case

// randomizes the order of elements in @seq
~shuffle = { |seq| seq.scramble };
// ~shuffle.value(~inBeats).postln; // test case

// creates pyramid of @seq using counting pattern of @type
~pyramid = { |seq, type = 1| seq.pyramid(type) };
// ~pyramid.value(~inBeats, 2).postln; // test case

/* ---------------  Mapping Sound to Symbols --------------- */

~k = List[]; // list for the kick drum
~s = List[]; // list for the snare drum
~h = List[]; // list for the hi-hat
~hH = List[];

~outBeats = List[]; // will hold resulting beats after transformations

// apply transforms at add to outBeats 2D array
~transforms.size.do {|i|
	if (~transforms[i] == \reverse,       {~outBeats.add(~backwards.value(~inBeats))});
	if (~transforms[i] == \invert,        {~outBeats.add(~invert.value(~inBeats, ~pattern))});
	if (~transforms[i] == \forward,       {~outBeats.add(~inBeats)});
	if (~transforms[i] == \shift,         {~outBeats.add(~shift.value(~shiftVal, ~inBeats, ~pattern))});
	if (~transforms[i] == \reverseInvert, {~outBeats.add(~invertBackward.value(~inBeats, ~pattern))});
	if (~transforms[i] == \shuffle,       {~outBeats.add(~shuffle.value(~inBeats))});
	if (~transforms[i] == \pyramid,       {~outBeats.add(~pyramid.value(~inBeats, ~pyramidVal))});
};

~outBeats = ~outBeats.flatten; // flatten 2D outBeats to 1D array

// create separate "parts" for each drum
~outBeats.size.do {|i|
	if (~outBeats[i] == \k,  {~k.add(0.25)},  {~k.add(Rest(0.25))});
	if (~outBeats[i] == \s,  {~s.add(0.25)},  {~s.add(Rest(0.25))});
	if (~outBeats[i] == \h,  {~h.add(0.25)},  {~h.add(Rest(0.25))});
	if (~outBeats[i] == \hH, {~hH.add(0.25)}, {~hH.add(Rest(0.25))});
};

~outBeats.postln;

s.sync;

~kick = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~k, ~measures),
		\buffer,     b[0],
		\pan,        ~pan[0],
		\amp,        Pseq(~amplitudes[0], ~measures)
	);
~snare = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~s, ~measures),
		\buffer,     b[1],
		\pan,        ~pan[1],
		\amp,        Pseq(~amplitudes[1], ~measures)
	);
~hat = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~h, ~measures),
		\buffer,     b[2],
		\pan,        ~pan[2],
		\amp,        Pseq(~amplitudes[2], ~measures)
	);
~hatOpen = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~hH, ~measures),
		\buffer,     b[3],
		\pan,        ~pan[3],
		\amp,        Pseq(~amplitudes[3], ~measures)
	);

Ppar([~kick, ~snare, ~hat, ~hatOpen], ~measures).play;

}
)