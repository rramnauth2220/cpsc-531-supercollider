/*

                  _        _        _                _
                 | |      (_)      | |              | |
  _ __ ___   __ _| |_ _ __ ___  __ | |__   ___  __ _| |_ ___
 | '_ ` _ \ / _` | __| '__| \ \/ / | '_ \ / _ \/ _` | __/ __|
 | | | | | | (_| | |_| |  | |>  <  | |_) |  __/ (_| | |_\__ \
 |_| |_| |_|\__,_|\__|_|  |_/_/\_\ |_.__/ \___|\__,_|\__|___/ V2

  Rebecca Ramnauth
  CSPC 531, Project 1 v.2, 30 Sept. 2019

  Version 1: All core deliverabes + stretch goals achieved, see original submission with line numbers
  Version 2: Implements more user control over beat samples and patterns
*/

(
s.waitForBoot {

/* ---------------  USER INPUTS  --------------- */

/*
	basic beat inputs, options:
	  \bd = bassdrum        \h  = hat          \r  = rest
	  \bl = bassline        \l  = loop
	  \fx = fx              \s  = snare
	  \g  = glitch          \p  = percussion
*/
~inBeats = [\bd, \fx];
~inSamples = [
		4, // sound bite # for bassdrum
		7, // sound bite # for bassline
		1, // sound bite # for fx
		4, // sound bite # for glitch
		5, // sound bite # for hat
		3, // sound bite # for loop
		1, // sound bite # for snare
		-1 // sound bite # for percussion
	]; // if -1, choose random sample from collection. Else, choose by index wrapped
~tempo = 1.2; // tempo
~beatLength = [
		0.25, // bassdrum
		0.25, // bassline
		0.75, // fx
		0.50, // glitch
		0.25, // hat
		0.25, // loop
		0.25, // snare
		0.25  // percussion
	]; // sound bite length in seconds
~beats = 4; // time signature
~measures = inf; // # of measures
~rate = 0.8; // audio rate
~pan = [
		 0.50, // bassdrum
		 0.25, // bassline
		 0.25, // fx
		 1.00, // glitch
		 0.50, // hat
		 1.00, // loop
		-0.25, // snare
		-0.25  // percussion
	]; // pan value for each sample from -1 (left) to 1 (right)
~amplitudes = [
		[1, 0.25, 0.75], // bassdrum
		[0.50, 0.75, 0.25, 0.25], // bassline
		[0.35, 0.35, 0.10], // fx
		[0.5, 1.0, 1.0], // glitch
		[0.5, 0.25, 0.75], // hat
		[0.3, 0.75, 0.5], // loop
		[0.5, 0.3, 0.5], // snare
		[0.3, 0.5, 0.23], // percussion
	];

// macro-structure inputs
~pattern = [\bd, \l, \bd, \r, \h, \s, \l, \r, \g, \fx, \s]; // originating pattern
~transforms = [
		\reverse,
		\invert,
		\forward,
		\shift,
		\reverseInvert,
		\shuffle,
		\pyramid
	]; // transformation sequence on input beat sequence (~inBeats) and possible transforms
~shiftVal = 3; // shift value, if shift is a requested transform
~pyramidVal = 1; // pyramid pattern type, if pyramid is a requested transform


/* ---------------  BEAT GENERATOR  --------------- */

// sound bites
~inSounds = [\bd, \bl, \fx, \g, \h, \l, \s, \p];

// set tempo
t = TempoClock.default;
t.tempo = ~tempo;
t.beats = ~beats;

// read sound files
~samples = List[];
// create separate "parts" for each drum
~inSounds.collect {|val|
	var path = PathName.new(("samples/" ++ val).resolveRelative);
	var files = path.files;
	~samples.add(files.collect {|file| Buffer.read(s, file.asRelativePath) });
	~samples[~samples.size - 1].free;
};

// define synth
SynthDef(\playBuf,
		{ |buffer, start = 0, dur = 0.25, pan, amp = 1|
	var sig = PlayBuf.ar(2, buffer, rate: ~rate, startPos: start, loop: 0);
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

~bd = List[]; // list for bassdrum
~bl = List[]; // list for bassline
~fx = List[]; // list for fx
~g  = List[]; // list for glitch
~h  = List[]; // list for hat
~l  = List[]; // list for loop
~s  = List[]; // list for snare
~p  = List[]; // list for percussion

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
		if (~outBeats[i] == \bd,  {~bd.add(~beatLength[0])},  {~bd.add(Rest(0.25))});
		if (~outBeats[i] == \bl,  {~bl.add(~beatLength[1])},  {~bl.add(Rest(0.25))});
		if (~outBeats[i] == \fx,  {~fx.add(~beatLength[2])},  {~fx.add(Rest(0.25))});
		if (~outBeats[i] == \g,   {~g.add(~beatLength[3])},   {~g.add(Rest(0.25))});
		if (~outBeats[i] == \h,   {~h.add(~beatLength[4])},   {~h.add(Rest(0.25))});
		if (~outBeats[i] == \l,   {~l.add(~beatLength[5])},   {~l.add(Rest(0.25))});
		if (~outBeats[i] == \s,   {~s.add(~beatLength[6])},   {~s.add(Rest(0.25))});
		if (~outBeats[i] == \p,   {~p.add(~beatLength[7])},   {~p.add(Rest(0.25))});
};

~outBeats.postln;

s.sync;

~bassdrums = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~bd, ~measures),
		\buffer,     if(~inSamples.size <= 0 || ~inSamples[0] == -1, ~samples[0][rrand(0, ~samples[0].size - 1)], ~samples[0].wrapAt(~inSamples[0])),
		\pan,        ~pan[0],
		\amp,        Pseq(~amplitudes[0], ~measures)
	);
~basslines = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~bl, ~measures),
		\buffer,     if(~inSamples.size <= 1 || ~inSamples[1] == -1, ~samples[1][rrand(0, ~samples[1].size - 1)], ~samples[1].wrapAt(~inSamples[1])),
		\pan,        ~pan[1],
		\amp,        Pseq(~amplitudes[1], ~measures)
	);
~effects = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~fx, ~measures),
		\buffer,      if(~inSamples.size <= 2 || ~inSamples[2] == -1, ~samples[2][rrand(0, ~samples[2].size - 1)], ~samples[2].wrapAt(~inSamples[2])),
		\pan,        ~pan[2],
		\amp,        Pseq(~amplitudes[2], ~measures)
	);
~glitches = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~g, ~measures),
		\buffer,      if(~inSamples.size <= 3 || ~inSamples[3] == -1, ~samples[3][rrand(0, ~samples[3].size - 1)], ~samples[3].wrapAt(~inSamples[3])),
		\pan,        ~pan[3],
		\amp,        Pseq(~amplitudes[3], ~measures)
	);
~hats = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~h, ~measures),
		\buffer,     if(~inSamples.size <= 4 || ~inSamples[4] == -1, ~samples[4][rrand(0, ~samples[4].size - 1)], ~samples[4].wrapAt(~inSamples[4])),
		\pan,        ~pan[3],
		\amp,        Pseq(~amplitudes[3], ~measures)
	);
~loops = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~l, ~measures),
		\buffer,     if(~inSamples.size <= 5 || ~inSamples[5] == -1, ~samples[5][rrand(0, ~samples[5].size - 1)], ~samples[5].wrapAt(~inSamples[5])),
		\pan,        ~pan[0],
		\amp,        Pseq(~amplitudes[0], ~measures)
	);
~snares = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~s, ~measures),
		\buffer,     if(~inSamples.size <= 6 || ~inSamples[6] == -1, ~samples[6][rrand(0, ~samples[6].size - 1)], ~samples[6].wrapAt(~inSamples[6])),
		\pan,        ~pan[0],
		\amp,        Pseq(~amplitudes[0], ~measures)
	);
~percussion = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~p, ~measures),
		\buffer,     if(~inSamples.size <= 7 || ~inSamples[7] == -1, ~samples[7][rrand(0, ~samples[7].size - 1)], ~samples[7].wrapAt(~inSamples[7])),
		\pan,        ~pan[0],
		\amp,        Pseq(~amplitudes[0], ~measures)
	);

Ppar([~bassdrums, ~basslines, ~effects, ~glitches, ~hats, ~loops, ~snares, ~percussion], ~measures).play;

}
)