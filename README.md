# CPSC 531 Supercollider Notes

**10-07-2019 Notice:** The purpose of this repository is to more easily share and discuss my work in CPSC 431/531 with current students. After this Fall 2019 semester, this repo will become private so as to protect the integrity of the assignments and future students' work. 

---------
**Rebecca Ramnauth** </br>
Computer Science PhD Student </br>
Yale University | AKW 507 | [rramnauth2220.github.io](rramnauth2220.github.io) </br>

---------
## Project 1: Matrix Beats

For the Matrix Beats project version 1, I used the default four samples (snare, high-hat, hat, kick) provided with Scott's starter code (I know, how unoriginal&mdash;but I do experiment with new samples and ways to organize them in version 2). This is to avoid wasting time on finding "good" samples and blaming any garbage output on my garbage inputs. 

### General Info
- audio recordings of system are posted on YouTube at [https://youtu.be/FabUtYX-XWY](https://youtu.be/FabUtYX-XWY) to demo how changing the inputs influences the outputs
- complete source code and samples are available on GitHub at [https://github.com/rramnauth2220/cpsc-531-supercollider/tree/master/RAMNAUTH-531-Project-1](https://github.com/rramnauth2220/cpsc-531-supercollider/tree/master/RAMNAUTH-531-Project-1)
- feel free to reach out to me about this project at [rebecca.ramnauth@yale.edu](mailto:rebecca.ramnauth@yale.edu)

### Determining User Inputs
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

### Relating Transforms to User Inputs
In context, the following method signatures emphasize the relationship between the backend logic and what/why the user can/should control the above inputs.

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

The algorithm for each method is straighforward and isn't inherently "creative". However, the process of measuring the relative distances (aka steps) between the input beat in the originating pattern is essential. Knowing the relative distances makes the transformations easier because a transformation method will first apply the transformation (e.g., inversion, shift, shuffle) to the array of relative distances before traversing the pattern array according to the new set of distances. This simplifies the code's logic because only one line per method needs to change to reflect the new transformation. For example:

```cpp
/* in ~invert */ var distances = ~getDistance.value(seq, pattern) * -1;
/* in ~shift  */ var distances = ~getDistance.value(seq, pattern) + shiftAmt;
```

If I decided to have more transformation methods, the process would be very similar to ```~invert``` and ```~shift```, where the general structure would be:

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

I've included example tests for each of the transformation methods in the full source code if you would like to explore these transforms more in isolation rather than in the context of the entire beat-making program. 

### Mapping Sound to Symbols

The user specifies in ```~transforms``` which transformations to apply as well as the order by which to apply them on their input beats (```~inBeats```). Creating the resulting sequence is accomplished by traversing the ```~transforms``` array and calling the appropriate transformation based on the current key. 

```cpp
// apply transforms and add to outBeats 2D array
~transforms.size.do {|i|
	if (~transforms[i] == \reverse,       {~outBeats.add(~backwards.value(~inBeats))});
	if (~transforms[i] == \invert,        {~outBeats.add(~invert.value(~inBeats, ~pattern))});
	if (~transforms[i] == \forward,       {~outBeats.add(~inBeats)});
	/* ... etc ... */
};
```

It seemed convenient to create a two-dimensional output array (```~outBeats```) to apply and keep track of the order of each transform, but this array is eventually flattened when the indices of each user-specified transform no longer matters. 

Finally, the sound stream for each sample is generated using a ```PBind``` such as the following: 

```cpp
~kick = Pbind(
		\instrument, \playBuf, // the synth def
		\dur,        Pseq(~k, ~measures), // how often to repeat kick sample
		\buffer,     b[0], // corresponding sample in buffer array
		\pan,        ~pan[0], // corresponding pan value as specified by user
		\amp,        Pseq(~amplitudes[0], ~measures) // map amplitudes and repeat according to no. of measures, both specified by user
	);
```

Similar ```PBind```s are implemented for the remaining samples. In version 2 of the Matrix Beats Project, I implemented a general PBind that is somewhat independent of the index of the corresponding sample file in the buffer array. This is so I can represent a collection of, for instance, bassdrums using only one ```PBind```. Furthermore, this adds a extra dimension of user-customization&mdash;being able to select even the specific sample used in the beat. 

```cpp
~bassdrums = Pbind(
		\instrument, \playBuf,
		\dur,        Pseq(~bd, ~measures),
		\buffer,     if(~inSamples.size <= 0 || ~inSamples[0] == -1, ~samples[0][rrand(0, ~samples[0].size - 1)], ~samples[0].wrapAt(~inSamples[0])), // get a sample from collection
		\pan,        ~pan[0],
		\amp,        Pseq(~amplitudes[0], ~measures)
	);
```

To better understand how this 'collection' is created, instead of creating array of the sample files, I create a list of samples by iterating the available sample directories:

```cpp
~samples = List[];
~inSounds.collect {|val|
	var path = PathName.new(("samples/" ++ val).resolveRelative);
	var files = path.files;
	~samples.add(files.collect {|file| Buffer.read(s, file.asRelativePath) });
	~samples[~samples.size - 1].free;
};
```

where ```~inSounds``` is an array of subdirectories containing samples: ```~inSounds = [\bd, \bl, \fx, \g, \h, \l, \s, \p];```. A file listing of the sample directory:

```cpp
Rebeccas-MacBook-Pro:~ rramnauth$ cd /Applications/SuperCollider/projects/RAMNAUTH-531-Project-1/RAMNAUTH-531-Project-1-V2/samples
Rebeccas-MacBook-Pro:samples rramnauth$ ls -l
total 0
drwxr-xr-x@  9 rramnauth  staff  288 Oct  3 14:32 FX
drwxr-xr-x@  9 rramnauth  staff  288 Oct  3 14:32 bd
drwxr-xr-x@ 15 rramnauth  staff  480 Oct  3 14:32 bl
drwxr-xr-x@  9 rramnauth  staff  288 Oct  3 14:32 g
drwxr-xr-x@  8 rramnauth  staff  256 Oct  3 14:32 h
drwxr-xr-x@  5 rramnauth  staff  160 Oct  3 14:32 l
drwxr-xr-x@  8 rramnauth  staff  256 Oct  3 14:32 p
drwxr-xr-x@ 14 rramnauth  staff  448 Oct  3 14:32 s
Rebeccas-MacBook-Pro:samples rramnauth$ 
```

Regardless of the sample input, the ```SynthDef``` is defined as:

```cpp
SynthDef(\playBuf,
		{ |buffer, start = 0, dur = 0.25, pan, amp = 1|
	var sig = PlayBuf.ar(1, buffer, rate: ~rate, startPos: start, loop: 0);
	var env = EnvGen.kr(Env.linen(0.01, dur, 0.01, level:amp), doneAction:2);
	OffsetOut.ar(0, Pan2.ar(sig, pan, env));
}).add;
```

Panning is possible per sample because it is given as a parameter in the ```SynthDef```, and its particular value can be specified in the ```PBind```s previously discussed.

### Further Directions

In my section on [Determining User Inputs](https://github.com/rramnauth2220/cpsc-531-supercollider#determining-user-inputs), I listed a bunch of seemingly arbitrary user inputs. However, I believe that, for computationally creative systems, the kinds of inputs the system receives and how it relates to the outputs it produces has an enormous impact on how creative the system is perceived to be.  My original idea was to obscure the relationship between the inputs and its output transformations&mdash;in other words, adding a dimension of mapping: input system to relevant inputs to resulting output. 

An example of such an 'input system' could be the sample library itself and mapping, for instance, the sentiment or popularity of each sample to 'relevant inputs' which may be amplitudes and panning values. In essence, the input system is the one input the user provides. It creates a kind of black-box obfuscation as to how the system works, which may then impact how creative the user perceives the system to be. Therefore, I strongly believe that a system's creativity is greatly influenced by its transparency. If the user can easily deconstruct the relationship between the inputs and the output, isn't the user more likely to percieve the system as uncreative? 

If I had more time to dedicate to this project, I would explore/implement one such input system. 

