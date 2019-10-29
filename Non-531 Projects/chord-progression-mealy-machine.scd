/*

10-09-2018 In-class coding with state machines and boring old tonality.

V2.102319

Use the following Events (or functions of your own design) to prototype a Mealy machine that:

On a state change:
  1) outputs 1
  2) causes a modulation from one key to another
Otherwise (no state change):
  1) causes a progression (I --> IV --> V) within a current key
  2) returns the progression (or modulation) as an array of MIDI chords: ex. [[60,64,67], [65,69,72], [67,71,74], [60,64,67]]. This can then be used in a Pseq, for example.

You can use the Mealy machine code below, or write your own.

--------------------------------------
Your mealy machine code must:

- Have at least two keys (ex. C and G)
- Take input symbols that, taken with the current state lead to a new state and give output.
- Output should be functional harmonic progressions such as I-IV-V-I
- When an input symbol (with current state) causes a state change (specifically, a modulation), your machine should allow for direct modulation (or tonicization) to either key (from either key) using a valid modulation formula taken below.


--------------------------------------
Your code may 1) choose from the below (non-deterministically) given all as options or 2) associate each progression with a specific state, such that you *might* move through them given different input symbols.

I-IV-V-I
I-ii-V-I
I-vi-V-I
I-IV-ii-V-I

Two Valid Modulations: FROM C to G

C: I-IV-(II-V)
G:       V -I

C: I-(vi-II-V)
G:    ii-V -I

Two Valid Modulations: FROM G to C

G: I-ii
C:   vi-IV-V-I

G: I-(IV)
C: V- I



Note the change of function (from minor ii to major II (V/V) when modulating from C to G.
Note vi is minor in both C and G and has largely the same function in both keys.

Difference between modulation and tonicization.

- Modulation establishes the new key with (ex) supertonic, dominant, tonic and then a valid chord progression in the new key.
- Tonicization is V/V and might not establish the new key with a valid chord progression. Tonicization is easy.


--------------------------------------
Below is a quick reference of chord functions and chords for C and G

C: I    ii    iii    IV    V    vi    vii*

   C    D     E      F     G    A     B
   E    F     G      A     B    C     D
   G    A     B      C     D    E     F

G: I    ii    iii    IV    V    vi    vii*

   G    A     B      C     D    E     F#
   B    C     D      E     F#   G     A
   D    E     F#     G     A    B     C

Remember that keys are based on scales and that scales are denoted by scale degrees.

Scale degrees are numbered 1-7. (But in computer languages, we count from 0, so 0-6)

*/


/* -------------------  GENERATING VALID CHORD PROGRESSIONS --------------------- */
~rules = [
	[2, 3, 4, 5, 6, 7],     // tonic         // I
	[1, 5, 7],              // supertonic    // ii
	[1, 4, 6],              // mediant       // iii
	[1, 2, 5, 7],           // subdominant   // IV
	[1, 4],                 // dominant      // V
	[1, 2, 3, 4, 5],        // submediant    // vi
	[1]                     // leading tone  // vii
];

// gives progression of @num length by traversing @map starting at element @start
~getProgression = {
	| map, num, start |
	var progression = [start];
	var current_node = start;
	for (0, num - 2, {
		arg i;
		var next_node = map[current_node - 1][(map[current_node - 1].size - 1).rand];
		progression = progression.add(next_node);
		current_node = next_node;
	});
	progression;
}

~testProgression = ~getProgression.value(~rules, 4, 1);

// in progress
// unit test, check if @in is a valid progression according to @rules
~isProgressionValid = {
	| rules, in |
	var valid = true;
	for (0, in.size - 2, {
		arg i;
		if (rules[i].contains(in[i + 1])) { } { valid = false };
	});
	valid;
};
// in progress
~isProgressionValid.value(~rules, ~testProgression);

(
SynthDef(\piano, { |out=0, freq=440, gate=1|
    var son = MdaPiano.ar(freq, gate, release: 0.9, stereo: 0.5, sustain: 0);
    DetectSilence.ar(son, 0.01, doneAction:2);
    Out.ar(out, son * 0.1);
}).add;
)

//~key = Scale.major;
//~key.degrees; // lists the semitone arrangement of the scale degrees of the major scale.
//~key.at([0,2,4]); // gets the tonic triad

~orientation = [0, 2, 4]; // tonic triad
~root = 5;

~getChords = {
	| key, orientation, root, progression, returnHome |
	var result;
	for (0, progression.size - 1, {
		arg i;
		result = result.add(key.at(orientation) + root + progression[i] + 60);
	});
	if (returnHome == true) { result = result.add(result[0]); };
	result;
};

~chords_1 = ~getChords.value(Scale.major, ~orientation, ~root, ~testProgression, true).midicps;
~chords_2 = ~getChords.value(Scale.minor, ~orientation, ~root + 1, ~testProgression, true).midicps;

Pbind(
	\instrument, \piano,
	\freq, Pseq(~chords_2, 1),
	\dur, 1
).play

// returns a progression of chords of orientation @orientation that reflects a scale of @root in @key of length @length
~getProgressionScale = {
	| key, root, length, orientation |
	var progression = ~getChords.value(key, orientation, root, Array.fill(length, { arg i; i + root; }), false);
	progression;
}; // test case // ~getProgressionScale.value(Scale.major, 0, 7, ~orientation)

/* -----------------------  MODULATION V. TONICIZATION ------------------------- */
~prevState = 0; // 0 = modulation, 1 = tonicization

// returns a set which is the intersection of arrays @from and @to
/* ~getPivotChords = {
	| from, to |
	var pivots;
	var f = from.asSet;
	var t = to.asSet;
	pivots = f & t;
} // musical theory error - pivots are between keys not chord progressions */

// returns a set which is the intersection of the keys @from and @to
~getPivotChords = {
	| from, to |


} // use ~getPivotChords.value(3, 5); // from e to g, but what about major/minor?

~pivotChords = ~getPivotChords.value(~chords_1, ~chords_1).asArray;

~getScaleDegree = {
	| map, dominant |
	var results;
	for (0, map.size - 1, {
		arg i;
		if(map[i].asSet.includes(dominant) && ((i + 1) != dominant)) { results = results.add(i + 1) };
	});
	results;
}

~getScaleDegree.value(~rules, 5); // gets items that are predominant

~getCommonPivots = {
	| map, pivots, degree |
	var d = ~getScaleDegree.value(map, degree);
	// to be continued
}

// in progress
~getCommonPivots.value(~rules, ~pivotChords, 5); // common pivots are defined as predominant chords

if (~pivotChords.size > 0) {
	/* use a diatonic-pivot modulation */
	var pivot = ~pivotChords[].cpsmidi).postln;

} { /* use a phrase modulation */}



/*
--------------------------------------
You code *might*
- Use Events for easy prototyping

--------------------------------------
Technical Notes: Stuff you will have to account for:

- You will need a way to keep track of your current state. Your current state should include the current chord, chord function, whether you are modulating, anything you will need to inform your state change.

- Use the Scale class to map triads onto keys

- Your code needs to associate
  1. chord functions (ex. tonic, subdominant, dominant) with
  2. chords (ex. [0,2,4], [3,5,7]) and
  3. Root MIDI level (ex. 60)

--------------------------------------
[FYI] Info on using Events (with default keys PARENT and custom keys PROTO can be found in the IdentityDictionary help file. This should not be necessary for getting started. See below.

*/

( // mealy
g = (in: 0, state: 0, output: 0,
	func: {
		case
		// initial state
		{g.state == i && (g.in == 1)} { "State 1".postln; g.state = 1; g.output = 0}
		{g.state == i && (g.in == 0)} { "State 0".postln; g.state = 0; g.output = 0}
		// state 0
		{g.state == 0 && (g.in == 0)} { "State 0".postln; g.state = 0; g.output = 0}
	    {g.state == 0 && (g.in == 1)} { "State 1".postln; g.state = 1; g.output = 1}
		// state 1
		{g.state == 1 && (g.in == 0)} { "State 0".postln; g.state = 0; g.output = 1}
	    {g.state == 1 && (g.in == 1)} { "State 1".postln; g.state = 1; g.output = 0}
		// default : if input not recognized
	    { "PLEASE USE VALID INPUT, DUMMY!".warn;};
	g.output}
)
)

(
g.in = rrand(0,1); // test with random binary input
g.state.postln;
g.func;
g.output.postln;
)


( // your class prototype (Event) or function(s) may go here. Note the below is INCOMPLETE and only exists to serve as a reference of how you *might* structure your program.

k = (

	cStat: \tonic, // current state: tonic, subdom, etc
	cFunc: (), // Event () or Function {} to associate root MIDI numbers or chord symbols with trichords ([0,2,4] which is 1-3-5 (triad) using the Scale class), etc
	key: (), // your key levels here (C, D, F, G, etc) - may itself be a function or Event
	scale: Scale.shang, // your key here .major, .minor, .shang
	roots: (\C: 60, \G: 55), // all the MIDI number roots for chords you want to generate
	chord: { (k.cStat).postln }, // create chords from above info
	modulate: { }; // function for modulating from key-to-key, generates V of new Tonic
);
)


// Access as follows:

k.cStat; // get
k.cStat = \subDom; // set
k.chord // using self keys 