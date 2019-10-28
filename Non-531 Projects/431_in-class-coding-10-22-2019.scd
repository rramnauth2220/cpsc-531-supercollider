/*

10-09-2018 In-class coding with state machines and boring old tonality.

V2.102219

Use the following Events (or functions of your own design) to prototype a Mealy machine that:

On a state change:
  1) outputs 1
  2) causes a modulation from one key to another
Otherwise (no state change):
  1) causes a progression (I --> IV --> V) within a current key
  2) returns the progression (or modulation) as an array of MIDI chords: ex. [[60,64,67], [65,69,72], [67,71,74], [60,64,67]]. This can then be used in a Pseq, for example.

You can use the Mealy machine code below, or write your own.

--------------------------------------
Your chord progression code must:
- Have at least two keys (ex. C and G)
- Be able to create functional harmonic progressions such as I-IV-V-I
- Be able to directly modulate (or tonicize) to either key (from either key) using V of that key. (Ex. C mod to G by playing D (D,F#,A))


--------------------------------------
Some Valid Progressions:

I-IV-V-I
I-ii-V-I
I-vi-V-I
I-IV-ii-V-I

Some Valid Modulations:

C: I-IV-II-V
G:      V -I

C: I-vi-II-V
G:   ii-V -I

Note the change of function (from minor ii to major II (V/V) when modulating. Note vi is minor in both C and G.

Difference between modulation and tonicization.

- Modulation establishes the new key with supertonic, dominant, tonic and then a valid chord progression
- Tonicization is V/V and might not establish the new key with a valid chord progression. Tonicization is easy.


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