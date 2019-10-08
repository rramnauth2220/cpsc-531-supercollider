# CPSC 531 Supercollider Notes

**10-07-2019 Notice:** The purpose of this repository is to more easily share and discuss my work in CPSC 431/531 with current students. After this Fall 2019 semester, this repo will become private so as to protect the integrity of the assignments and future students' work. 

---------
**Rebecca Ramnauth** </br>
Computer Science PhD Student </br>
Yale University | AKW 507 | [rramnauth2220.github.io](rramnauth2220.github.io) </br>

---------
For the Matrix Beats project version 1, I used the default four samples (snare, high-hat, hat, kick) provided with Scott's starter code (I know, how unoriginal&mdash;but I do experiment with new samples and ways to organize them in version 2). This is to avoid blaming any garbage output on my garbage inputs. 

To begin, I needed to establish which inputs the user should control versus which methods/variables should be somewhat beyond the non-programmer's reach. Below is a description of a few highlighted user inputs.

```cpp
// basic beat inputs
~inBeats = [\k, \s, \h, \hH]; // underlying beat
~tempo = 1.5; // tempo
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
	]; // transformation sequence on input beat sequence (~inBeats)
~shiftVal = 0; // shift value, if shift is a requested transform
~pyramidVal = 1; // pyramid pattern type, if pyramid is a requested transform
```

In context, the following method signatures emphasize the relationship between the back-end logic what/why the user can/should control the above inputs.

```cpp
/* ---------------  Helper Functions  --------------- */
// returns index of @element in @pattern
~getIndex = { | element, pattern | /* ... */ };

// returns distances of each element in @beats relative to indices in @pattern
~getDistance = { | beats, pattern | /* ... */ };

/* ---------------  Transformation Methods  --------------- */

// reverse beat sequence @seq
~backwards = { |seq| /* ... */ };

// inverts @seq using relative steps found in @pattern
~invert = { |seq, pattern| /* ... */ };

// shifts @seq by @shiftAmt steps according to @pattern
~shift = { |shiftAmt, seq, pattern| /* ... */ };

// inverts @seq, then reverses resulting sequence
~invertBackward = { |seq, pattern| /* ... */ };

// randomizes the order of elements in @seq
~shuffle = { |seq| /* ... */ };

// creates pyramid of @seq using counting pattern of @type
~pyramid = { |seq, type = 1| /* ... */ };

```

The algorithmic for each method is straighforward and isn't inherently "creative". However, the process of measuring the relative distances (aka steps) between the input beat in the originating pattern is essential. Knowing the relative distances makes the transformations easier because a transformation will first apply the "transformation" (e.g., inversion, shift, shuffle) to the array of relative distances before traversing the pattern array according to the new set of distances. This simplifies the code's logic because only one line per method needs to change to reflect the new transformation. For example:

```cpp
/* in ~invert */ var distances = ~getDistance.value(seq, pattern) * -1;
/* in ~shift  */ var distances = ~getDistance.value(seq, pattern) + shiftAmt;
```

If I decided to have more transformation methods, the process would be very similar to ```~invert``` and ```~shift```, where:

```cpp
~method_name = { |seq, pattern, additional_params|
        var result = [];
        var distances = ~getDistance.value(seq, pattern) * [transform]; // get steps and apply transform
        var origin = 0;
        for (0, seq.size - 1) { |i| // loops through sequence
            origin = distances[i] + origin; // recalculate index from steps
            result = result.add(pattern.wrapAt(origin));
        };
        result; // return transformed array
    };
```

With this said, the number of transformation methods I decide to have truly depends on how much time I want to dedicate to this portion of the project. It's really a matter of finding new transformation ideas and mathematically manipulating the relative distances.



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
```