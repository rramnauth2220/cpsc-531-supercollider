/*
    Text-based sentiment analysis and music emotion recognition
    Rebecca Ramnauth - Final Project - CPSC 531
    v.12102019
*/

(
s.waitForBoot {

	~debug = false;
	// s.options.memSize = 65536; // for testing

	/* ---------  Synth Definitions  ---------- */
	SynthDef(\mdapiano,
		{ |out=0, freq=440, gate=1, vel=80|
			var son = MdaPiano.ar(freq, gate, vel, 0.4, 0.2, stereo: 0.3, sustain: 0);
			DetectSilence.ar(son, 0.01, doneAction:2);
			Out.ar(out, son * 0.1);
	}).add;

	SynthDef(\piano, { |out=0, freq=440, gate=1|
		var son = MdaPiano.ar(freq, gate, release: 0.9, stereo: 0.5, sustain: 0.05);
		DetectSilence.ar(son, 0.01, doneAction:2);
		Out.ar(out, son * 0.1);
	}).add;

	SynthDef(\drone,
	{ | out = 0, speed = 1, amp = 0.5, rel = 0.5, dur = 1, freq=200 |
		var base = LFNoise1;
		var adsr = EnvGen.ar(Env.linen(dur * 1, rel, 0.1, 1, -3), doneAction: 2);
		var sig = HPF.ar(FreeVerb2.ar(*XFade2.ar(SinOscFB.ar([20, freq],base.ar(speed * 2) + 1 / 8),
		SinOscFB.ar([freq, 25],base.ar(speed) + 1 / 2),base.ar(20))), 120);
		sig = HPF.ar(sig, 100);
		sig = GVerb.ar(sig);
		sig = (sig * adsr);
		Out.ar(out, sig * amp);
	}).add;

	SynthDef(\bass,
	{ | out = 0, amp = 1, b = 2, rel = 15, freq = 440 |
		var bass, s1, f, lag, d;
		var env = EnvGen.ar(Env.linen(0.0, rel, 0), doneAction: 2);
		d = Duty.kr(b * 4, 0, Dseq([b, b * 2, b * 4, b / 2],inf));
		lag = Duty.kr(b * 4, 0, Dseq([0.2, 0.1, 0.08, 0.02, 0.052, 0.12],inf)).lag(0.2);
		s1 = SinOsc.ar(Lag.kr([freq, freq]), mul: 0.2) * Decay2.kr(Impulse.kr([b / 16, b / 8]), 0.4,decayTime: b * 4);
		s1 = FreeVerb.ar(s1, room: 2, mul: 0.5, add: s1);
		Out.ar(out,(s1 * amp) * env);
	}).add;

	/* ---------------  General Helper Functions  --------------- */

	// return all but first element of @arr
	~tail = {
		| arr |
		var tail = [];
		for (1, arr.size - 1, {
			arg i;
			tail = tail.add(arr[i]);
		});
		tail;
	};

	// return set of unique items in multidimensional @arr
	~getUniqueKeys = {
		| arr, flatten = false |
		if (flatten, { arr.flatten.asSet }, { arr.asSet });
	};

	// return items of @sample that exist in @container
	~getExistingOnly = {
		| sample, container |
		var keys = container.keys & sample;
		keys;
	};

	// return corresponding values for @keys according to @container
	~getValues = {
		| keys, container |
		var values = [];
		var keys_arr = keys.asArray;
		for (0, keys_arr.size - 1, {
			arg i;
			values = values.add(container.at(keys_arr[i]));
		});
		values;
	};

	// determine number of instances of @item in multidimensional @container
	~getFrequency = {
		| container, item, flatten = false |
		var count = 0;
		var container_flat = if (flatten, { container.flatten }, { container });
		for (0, container_flat.size - 1, {
			arg i;
			if (container_flat[i] == item, { count = count + 1; });
		});
		count;
	};

	// return index of @element in @pattern
	~getIndex = { | element, pattern |
		var index = 0;
		while ( { (pattern[index] != element)
			&& (index < pattern.size) },
		{ index = index + 1; });
		if (index >= pattern.size, -1, index);
	}; // ~getIndex.value(\c, ~inBeats).postln; // test case

	// return distances of each element in @beats relative to indices in @pattern
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

	// return array of frequencies of elements of @set in @arr
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

	// return @size most common elements in @set according to @freq
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

	// return sample standard deviation of elements in @arr
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

	// return minimum item in @arr
	~getMinimumValue = {
		| arr |
		var minimum = arr[0];
		for (1, arr.size - 1, { arg i;
			if (arr[i] < minimum) {
				minimum = arr[i];
			};
		});
		minimum;
	};

	// return the key corresponding to the maximum value in @dictionary
	~getKeyOfMaximum = {
		| dictionary |
		var keys = dictionary.keys.asArray;
		var maximum = keys[0];
		for (1, keys.size - 1, {
			arg i;
			if (dictionary.at(keys[i]) > dictionary.at(maximum)) { maximum = keys[i] };
		});
		maximum;
	};

	// shift each element of @arr by @amount
	~shiftValues = {
		| arr, amount |
		var shifted_arr = [];
		for (0, arr.size - 1, {
			arg i;
			shifted_arr = shifted_arr.add(arr[i] + amount);
		});
		shifted_arr;
	};

	// get the @index-th element of each item in @container
	~getEachNthElement = {
		| container, index |
		var subcontainer = [];
		for (0, container.size - 1, {
			arg i;
			subcontainer = subcontainer.add(container[i][index]);
		});
		subcontainer;
	};

	// remove non-numeric items in @arr
	~removeNonNumeric = {
		| arr |
		var strip_arr = [];
		for (0, arr.size - 1, {
			arg i;
			if(arr[i].isNumber) { strip_arr = strip_arr.add(arr[i]); }
		});
		strip_arr;
	};

	// relate @keys to @item in a Dictionary object
	~mapAsDictionary = {
		| items, keys |
		var d = Dictionary.new;
		for (0, items.size - 1, {
			arg i;
			d.add(keys[i] -> items[i]);
		});
		d;
	};

	// return Dictionary that is the union of items in @subcontainer and @container
	~extract = {
		| container, subcontainer |
		var subcontainer_dictionary = Dictionary.new;
		var subcontainer_set = subcontainer.asSet;
		var keys = container.keys.asArray;
		for (0, keys.size - 1 , {
			arg i;
			if (subcontainer_set.includes(keys[i])) {
				subcontainer_dictionary.add(keys[i] -> container.at(keys[i]))
			};
		});
		subcontainer_dictionary;
	};

	/* ---------------  Text Analysis Helper Methods --------------- */

	// remove line breaks and whitespace in @arr
	~removeWhitespace = {
		| arr |
		for (arr.size - 1, 0, {
			arg i;
			if (arr[i].size <= 1, { arr.removeAt(i); }); // line breaks
			for (arr[i].size - 1, 0, {
				arg j;
				if (arr[i][j].size <= 0, { arr[i].removeAt(j); }); // whitespace
			});
		});
		arr;
	};

	// create dictionary using @lex values and @order keys
	~convertToDictionary = {
		| lex, order = nil |
		var d = Dictionary.new;
		if (order != nil, { /* sentiment order specified */
			for (0, lex.size - 1, {
				arg i;
				var tail = ~tail.value(lex[i]);
				var tail_sentiment = Dictionary.new;
				for (0, tail.size - 1, {
					arg j;
					tail_sentiment.add(order[j] -> tail[j]);
				});
				d.add(lex[i][0] -> tail_sentiment);
		})}, { /* sentiment order not specified */
			for (0, lex.size - 1, {
				arg i;
				var tail = ~tail.value(lex[i]);
				d.add(lex[i][0] -> tail);
			});
		});
		d;
	};

	// tally sentiment @values using @key frequency in @text
	~enumerateSentiment = {
		| text, keys, values |
		var keys_arr = keys.asArray;
		var sentiment = Array.fill(values[0].size, 0);
		for (0, keys_arr.size - 1, {
			arg i;
			var frequency = ~getFrequency.value(text, keys_arr[i], true);
			for (0, values[i].size - 1, {
				arg j;
				sentiment[j] = sentiment[j] + (values[i][j].asInteger * frequency);
			});
		});
		sentiment;
	};

	// tally sentiment @values using @key frequency in @text
	// self-contained/modularized version of ~enumerateSentiment
	~enumerateSentiment_module = {
		| text, lex, flatten = false, length = 10 |

		var uniques = ~getUniqueKeys.value(text, flatten);
		var keys = ~getExistingOnly.value(uniques, lex).asArray;
		var values = ~getValues.value(keys, lex);
		var sentiment = Array.fill(length, 0);

		if (keys.notNil && keys.size > 0) {
			for (0, keys.size - 1, {
				arg i;
				var frequency = ~getFrequency.value(text, keys[i], flatten);
				for (0, values[i].size - 1, {
					arg j;
					sentiment[j] = sentiment[j] + (values[i][j].asInteger * frequency);
				});
			});
		};
		sentiment;
	};

	// parse @arr by sentiment values per item (line, paragraph, section) found in @lex
	// return array of sentiment value
	// context issue: phrase item often too short to have significant max/min sentiment differences, thus unreliable factor in text-to-music mapping
	~enumerateSentiments = {
		| arr, lex, flatten = false, length = 10 |
		var sentiments = [];
		for (0, arr.size - 1, {
			arg i;
			var sentiment = ~enumerateSentiment_module.value(arr[i], lex, flatten, length);
			sentiments = sentiments.add(sentiment);
		});
		sentiments;
	};

	// return total word count of @arr
	~wordCount = { | arr | arr.flatten.size; };

	// return average word count per item in @arr
	~wordsPerLine = { | arr | (~wordCount.value(arr) / arr.size); };

	// determine if @letter is a vowel=true or consonant=false
	~isVowel = {
		| letter |
		if ("aeiou".contains(letter), { true }, { false });
	};

	// tally the number of vowels in @word
	~vowelCount = {
		| word |
		var vowels = ["a", "e", "i", "o", "u"];
		var vowel_count = 0;
		//word.findAll("l").postcs;
		for (0, vowels.size - 1, {
			arg i;
			vowel_count = vowel_count + word.findAll(vowels[i]).size;
		});
		vowel_count;
	};

	// generate permutations of @length letters in @word
	~permutations = {
		| word, length |
		var permutations = [];
		if (word.size >= length, {
			for (0, word.size - length, {
				arg i;
				var permutation = "";
				for (0, length - 1, {
					arg j;
					permutation = permutation + word[i + j];
				});
				permutations = permutations.add(permutation);
			});
		});
		permutations;
	};

	// determine number of -phthong (vowel patterns of length @prefix) in @word
	~phthongCount = {
		| word, prefix |
		var permutations = ~permutations.value(word, prefix);
		var phthongCount = 0;
		for (0, permutations.size - 1, {
			arg i;
			if (permutations[i].size > 0 && permutations[i].notNil){
				if (~vowelCount.value(permutations[i]) == (permutations[i].size - 2), { phthongCount = phthongCount + 1; });
			};
		});
		phthongCount;
	};

	// return number of syllables in @word
	~syllableCount = {
		| word |
		var syllables = 0;

		// word characteristics by vowel relationships
		var vowels = ~vowelCount.value(word);
		var diphthong = ~phthongCount.value(word, 2);
		var triphthong = ~phthongCount.value(word, 3);

		// consider suffix overlap
		// check "consonant + le" suffix
		var suffix = 0;
		/*if (word.size >= 4){
			if (word.endsWith("le") && (~isVowel.value(word[word.size - 3]) == false),
				{ suffix = 1; },
				{ // else check "consonant + les" suffix
					if ((word.endsWith("les")) && (~isVowel.value(word[word.size - 4]) == false),
						{ suffix = 1; }
					);
			});
		};*/

		syllables = vowels - (diphthong + triphthong); // + suffix;
		syllables;
	};

	// return total number of syllables in @arr
	~totalSyllableCount = {
		| arr |
		var arr_flat = arr.flatten;
		var count = 0;
		for (0, arr_flat.size - 1, {
			arg i;
			count = count + ~syllableCount.value(arr_flat[i]);
		});
		count;
	};

	// return average number of syllables per item in @arr
	~averageSyllablesPerLine = {
		| arr |
		(~totalSyllableCount.value(arr) / arr.size);
	};

	/* ---------------  Music Analysis Helper Methods --------------- */

	// return midi data of @size files in midi directory at @path
	// @size is optionally specified; if @size = -1 read all files, else read @size files
	~getPhrases = {
		| path, size = -1 |
		var subjects = PathName.new(path.resolveRelative).entries;
		var elements = [];
		size = if (size == -1, { subjects.size }, { size });
		for (0, size - 1, {
			arg i; // index

			// convert file > midi > pattern > stream
			var midi = SimpleMIDIFile.read(subjects[i].asRelativePath);
			var pattern = midi.patternize;
			var stream = pattern.asStream;

			// read midi data
			var element; var data = [];
			// var notes = []; var durations = []; var amplitudes = [];

			(">" + subjects[i].asRelativePath).postln;
			try {
				while{ (element = stream.next(Event.default)).notNil } {
					data = data.add([element.midinote, element.dur, element.amp]);
					//notes = notes.add(element.midinote);
					//durations = durations.add(element.dur);
					//amplitudes = amplitudes.add(element.amp);
				};
			} { | error | /* ?endofstream nil not accounted for by while */
				error.asString.warn;
			};

			// add midi event data
			elements = elements.add(data);
		});
		elements;
	};

	// determine octave according to @sentiment
	// map @sentiment to given octave range [@outMin, @outMax]
	~calculateOctave = {
		| sentiment, inMin, inMax, outMin, outMax |
		var positive_density = (sentiment.at(\joy) + sentiment.at(\positive))/2;
		var negative_density = (sentiment.at(\sadness) + sentiment.at(\negative))/2;
 		var output = (positive_density - negative_density).linlin(inMin, inMax, outMin - 1, outMax);
		output;
	};

	// determine octave for non-main melody using @negative:@positive ratio of @dictionary items
	~reinforceOctave = {
		| dictionary, negative, postive, weight = 1 |
		var adjustVal = 0;
		var prevalent = ~getKeyOfMaximum.value(dictionary);
		var negative_emotions = negative.asSet;
		var positive_emotions = negative.asSet;
		if (positive_emotions.includes(prevalent)) { adjustVal = adjustVal + weight };
		if (negative_emotions.includes(prevalent)) { adjustVal = adjustVal - weight };
		adjustVal;
	};

	/* ---------------  Mapping Symbols to Sound  --------------- */

	if (~debug == false) {

		var voice = true;        // main line
		var playthrough = true;  // primary melody
		var melody = true;       // secondary melody

		var chain_length = 100; var chain_order = 2;

		var sentiment_order = [
			\positive, \negative, \anger, \anticipation,
			\disgust, \fear, \joy, \sadness, \surprise, \trust
		]; // order matters when parsing lexicon
		var emolex = FileReader.read( // parse emotion-lexicon
			"emotion-lexicon/emolex_english.csv".resolveRelative, true, true, delimiter: $,);
		var input = FileReader.read("input/phenomenal-woman.txt".resolveRelative, false, true);

	    /* ---------------  Text Analysis --------------- */

		var input_wordCount = ~wordCount.value(input);
		var input_wordCountPerLine = ~wordsPerLine.value(input);
		var input_totalLines = input.size;
		var input_syllableCount =
		//~permutations.value("a", 2);       //test generating permutations
		//~phthongCount.value("a", 2);       //test determining vowel patterns
		//~syllableCount.value("hello");     //test determining syllable count of item
		//~totalSyllableCount.value(input);  //test determining syllable count of array
		~averageSyllablesPerLine.value(input);

		// preprocessing
		var lex = ~convertToDictionary.value(emolex /*, sentiment_order*/); // map as dictionary of sentiments
		var text = ~removeWhitespace.value(input); // remove extraneous linebreaks and whitespace

		// infer sentiment
		var uniques = ~getUniqueKeys.value(text, true);
		var existing_keys = ~getExistingOnly.value(uniques, lex);
		var existing_values = ~getValues.value(existing_keys, lex);
		var sentiment_density = (~enumerateSentiment.value(text, existing_keys, existing_values)/input_wordCount);

		// extract emotions
		var sentiment_dictionary = ~mapAsDictionary.value(sentiment_density, sentiment_order).postcs;
		var emotion_dictionary = ~extract.value(sentiment_dictionary,
			[\anger, \anticipation, \disgust, \fear, \joy, \sadness, \surprise, \trust]);

		/* ---------------  Musical Analysis --------------- */

		// determine appropriate training pool based on most prevalent emotion
		var prevalent_emotion = ~getKeyOfMaximum.value(emotion_dictionary);
		var modified_path = ("midi/"++ prevalent_emotion ++ "/");

		// determine macro elements of output based on text analysis
		var scale_major = if(((sentiment_dictionary.at(\positive) - sentiment_dictionary.at(\sadness)) > 0), { Scale.major }, { Scale.minor });
		var octave = ~calculateOctave.value(sentiment_dictionary, (-1 * existing_keys.size/input_wordCount), (existing_keys.size/input_wordCount), 3, 7);
		var melody_octave = octave + ~reinforceOctave.value(emotion_dictionary, [\anger, \fear, \sadness, \disgust], [\joy, \trust], 1);
		// TempoClock.default.tempo = 2.5; // next steps: incorporate syllable count/movement into tempo

		// parse training midi data
		var raw_data = ~getPhrases.value(modified_path);
		var raw_index = rrand(0, raw_data.size - 1);
		var raw_notes = ~getEachNthElement.value(raw_data[raw_index], 0);
		var raw_durations = ~getEachNthElement.value(raw_data[raw_index], 1);
		var raw_amplitudes = ~getEachNthElement.value(raw_data[raw_index], 2);

		// generate Markov sets
		var m_notes = MarkovSetN.fill(chain_length, Pseq(raw_notes).asStream, chain_order);
		var m_durations = MarkovSetN.fill(chain_length, Pseq(raw_durations).asStream, chain_order);
		var m_amplitudes = MarkovSetN.fill(chain_length, Pseq(raw_amplitudes).asStream, chain_order);

		if (melody) {
			// determine best length
			var melody_length = ~calculateSD.value(raw_notes).round(1);

			// determine most appropriate notes
			var note_frequencies = ~getFrequencies.value(raw_notes, raw_notes.asSet.asArray);
			var melody_notes = ~getNCommon.value(note_frequencies, raw_notes.asSet.asArray, melody_length);

			// determine most appropriate durations
			var duration_frequencies = ~getFrequencies.value(raw_durations, raw_durations.asSet.asArray);
			var melody_durations = ~getNCommon.value(duration_frequencies, raw_durations.asSet.asArray, melody_length);

			// determine most appropriate amplitudes
			var amplitude_frequencies = ~getFrequencies.value(raw_amplitudes, raw_amplitudes.asSet.asArray);
			var melody_amplitudes = ~getNCommon.value(amplitude_frequencies, raw_amplitudes.asSet.asArray, melody_length);

			s.sync;

			// play it
			Pbind(\instrument, \bass,
				\freq, Pseq(melody_notes.midicps, inf),
				\dur, Pseq(melody_durations, inf),
				\amp, Pseq(melody_amplitudes.normalize(min: 0, max: 0.2), inf)
			).play;
		};

		if (voice || playthrough) {

			// generate notes
			m_notes.makeSeeds;
			~m_notes_stream = m_notes.asStream;
			~m_notes_stream.next([0, 2]);
			~markov_notes = Array.fill(raw_notes.size, {~m_notes_stream.next});

			// generate durations
			m_durations.makeSeeds;
			~m_durations_stream = m_durations.asStream;
			~m_durations_stream.next([0, 2]);
			~markov_durations = Array.fill(raw_durations.size, {~m_durations_stream.next});

			// generate amplitudes
			m_amplitudes.makeSeeds;
			~m_amplitudes_stream = m_amplitudes.asStream;
			~m_amplitudes_stream.next([0, 2]);
			~markov_amplitudes = Array.fill(raw_amplitudes.size, {~m_amplitudes_stream.next});

			s.sync;

			// play voice
			if (voice) {
				Pbind(\instrument, \drone,
					\freq, Pseq(~markov_notes.midicps, inf),
					\speed, Pseq(~markov_durations, inf),
					\amp, Pseq(~markov_amplitudes, inf))
				.play;
			};

			// process playthrough
			if (playthrough) {
				var variability = ~calculateSD.value(~markov_notes).round(1);
				var shiftAmount = ~getMinimumValue.value(~markov_notes).postln;
				var shifted_notes = ~shiftValues.value(~markov_notes, shiftAmount * -1);
				var stripped_notes = ~removeNonNumeric.value(shifted_notes);
				var new_notes = stripped_notes.normalize(min: 0, max: variability);

				s.sync;

				// play it
				Pbind(
					\instrument, \piano,
					\scale, Scale.major,
					\degree, Pseq(new_notes, inf),
					\dur, 0.5,
					\octave, octave,
					\root, 3,
					\vel, 0.5,
					\legato, 0.95
				).play;
			};
		};
	};
})