/*  CPSC 531 - Chord Progression Mealy Machine - 10302019 */

(
s.waitForBoot {

	/* ---------------  Inputs  --------------- */

	~rules = [ // on generating 'valid' chord progressions
		[2, 3, 4, 5, 6, 7],     // tonic         // I
		[1, 5, 7],              // supertonic    // ii
		[1, 4, 6],              // mediant       // iii
		[1, 2, 5, 7],           // subdominant   // IV
		[1, 4],                 // dominant      // V
		[1, 2, 3, 4, 5],        // submediant    // vi
		[1]                     // leading tone  // vii
	];

	~orientation = [0, 2, 4]; // tonic triad
	~progression_length = 4; // create a progression of size 4
	~start_degree = 1; // start on tonic
	~scale = Scale.major; // [1, 2, 5, 6, 7, 9, 12]; // or can use Scale.major/minor/shang
	~keys = [0, 1, 5, 2, 5, 7]; // keys to modulate between

	/* ---------------  Synth Definitions  --------------- */

	SynthDef(\piano, { | out = 0, freq = 440, gate = 1 |
		var son = MdaPiano.ar(freq, gate, release: 0.9, stereo: 0.5, sustain: 0);
		DetectSilence.ar(son, 0.01, doneAction:2);
		Out.ar(out, son * 0.1);
	}).add;

	/* ---------------  Helper Functions  --------------- */

	// gives progression of @num length by traversing @map starting at element @start
	~getProgression = {
		| map, num, start = 1 |
		var progression = [start];
		var current_node = start;
		for (0, num - 2, {
			arg i;
			var next_node = map[current_node - 1][(map[current_node - 1].size - 1).rand];
			progression = progression.add(next_node);
			current_node = next_node;
		});
		progression;
	}; // test case // ~getProgression.value(~rules, 4, 1);

	// return a dictionary object after applying @progression using @orientation starting from @root in @key
	~getChords = {
		| key, orientation, root, progression, returnHome = false |
		var chords;
		var result = Dictionary.new;
		for (0, progression.size - 1, {
			arg i;
			chords = chords.add(key.at(orientation) + root + progression[i] + 60);
		});
		if (returnHome == true) { chords = chords.add(chords[0]); };

		result.add(\chords -> chords);
		result.add(\key -> key);
		result.add(\root -> root);
		result.add(\orientation -> orientation);
		result.add(\progression -> progression);

		result;
	}; // test case // ~getChords.value(Scale.major, ~orientation, ~root - 6, ~testProgression, true);

	// returns a dictionary object which is a progression of chords
	// of orientation @orientation that reflects a scale of @root in @key of length @length
	~getProgressionScale = {
		| key, root, length, orientation |
		var progression = ~getChords.value(key, orientation, root, Array.fill(length, { arg i; key[i]; }), false);
		progression;
	}; // test case // ~getProgressionScale.value(Scale.minor, 0, 7, ~orientation);

	// 'Modulation establishes the new key with (ex) supertonic, dominant, tonic
	// and then a valid chord progression in the new key.'
	// --> does this mean the pivot chord also needs to follow the progression?
	// --> is that possible?
	~getPreScaleDegree = {  // deciding on a pivot // purpose: Western tonality prefers pivot = predominant
		| map, degree |
		var results;
		for (0, map.size - 1, {
			arg i;
			if(map[i].asSet.includes(degree) && ((i + 1) != degree)) { results = results.add(i + 1) };
		});
		results;
	}; // test case // ~getPreScaleDegree.value(~rules, 5); // gets items that are predominant

	/* // returns a set which is the intersection of arrays @from and @to
	~getPivotChords = {
	| from, to |
	var pivots;
	var f = from.asSet;
	var t = to.asSet;
	pivots = f & t;
	} // musical theory error - pivots are between keys not chord progressions
	  // generalized for progressions as well as keys below
	*/

	// returns a set which is the intersection of the keys @from and @to
	// WIP: optimizing this, inputs only from's key + root, to's key and root
	// ideal for pivots between keys and progressions
	~getPivotChords = {
		| from, to |
		var from_scale = ~getProgressionScale.value(from.at(\key), from.at(\root), ~scale.size, from.at(\orientation));
		var to_scale = ~getProgressionScale.value(to.at(\key), to.at(\root), ~scale.size, to.at(\orientation));
		var pivots = from_scale.at(\chords).asSet & to_scale.at(\chords).asSet;
		pivots;
	}; // test case // ~getPivotChords.value(~getProgressionScale.value(Scale.major, 0, 7, [0, 2, 4]), ~getProgressionScale.value(Scale.major, 0, 7, [0, 2, 4])).asArray;

	// return chords of @progression in scale of @scale
	~followProgression = {
		| progression, scale |
		var chords;
		for (0, progression.size - 1, {
			arg i;
			chords = chords.add(scale.at(\chords)[progression[i] - 1]);
		});
		chords;
	}; // test case // ~followProgression.value(~testProgression, ~testScale);

	/* ---------------  Transformation Methods  --------------- */

	// compute modulation with pivot chord at @pivot_index between @from and @to keys
	~getModulation = {
		| map, from, to, progression, degree, pivot_index = -1 |
		var from_chords = ~followProgression.value(progression, from);
		var to_chords = ~followProgression.value(progression, to);
		//var preference = ~getPreScaleDegree.value(map, degree); // next steps, choosing a pivot chord
		var pivots = (from.at(\chords).asSet & to.at(\chords).asSet).asArray;
		var pivot = pivots[pivots.size.rand];
		var result;
		if (pivot_index <= 0) { // cannot have pivot index to be 0, else not a modulation
			/* no split in progression among keys */
			for (0, progression.size - 1, { arg i; result = result.add(from_chords.at(i)); });
			result = result.add(pivot);
			for (0, progression.size - 1, { arg i; result = result.add(to_chords.at(i)); });
		} { /* split progression among keys */
			for (0, pivot_index - 1, { arg i; result = result.add(from_chords.at(i)); });
			result = result.add(pivot);
			for (pivot_index, progression.size - 1, { arg i; result = result.add(to_chords.at(i)); });
		};
		result;
	};

	// test case
	/*
	~resultMod = ~getModulation.value(
		~rules,
		~getProgressionScale.value(Scale.major, 0, 7, ~orientation),
		~getProgressionScale.value(Scale.major, 5, 7, ~orientation),
		~testProgression,
		5,
		0
	); */ // next steps, common-chord pivots are defined as predominant chords

	~getLine = {
		| map, keys, progression, degree = 5, split = 0 |
		var result;
		var prev_key = keys.at(0); // keep track of previous state
		for (1, keys.size - 1, {
			arg i;
			var r = ~getModulation.value(
				map,
				~getProgressionScale.value(~scale, prev_key, ~scale.size, ~orientation),
				~getProgressionScale.value(~scale, keys[i], ~scale.size, ~orientation),
				progression,
				degree,
				split
			);
			prev_key = keys[i]; // update state
			for (0, r.size - 1, { arg i; result = result.add(r[i]); });
		});
		result;
	}; // test case // ~getLine.value(~rules, [0, 5, 2], ~testProgression);

	/* ---------------  Putting it Together --------------- */

	~inProgression = ~getProgression.value(~rules, ~progression_length, ~start_degree);
	~outputLine = ~getLine.value(~rules, ~keys, ~inProgression);
	~outputLine.postln;

	s.sync;

	Pbind(
		\instrument, \piano,
		\freq, Pseq(~outputLine.midicps, 1),
		\dur, 1
	).play;
}
)

/* ----------------------- Assignment Instructions ------------------------- */
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