/*
Rebecca Ramnauth
CPSC 531 Homework 2
20 Sept. 2019
*/


/* Problem 1.

Use () and {} to define an expression that:

  • Defines two variables, one of which (variable one) is available to both structures and one (variable two) is only available within the inner structure { }.
  • Assigns integers to both variables.

When evaluated, the expression should:
  • multiply the variables
  • post the results to the post window.

*/

(
var var1 = 6;
({
	var var2 = 5;
	var2.postln;
}.value * var1).postln;
)


/* Problem 2.

Write an expression that:
  • Randomly chooses eight integers between 0 and 10 (with no duplicates)
  • Uses the .add method to add them to an Array resulting in an array of size 8.
  • Assigns the array to an environmental variable.
  • Prints the variable to the post window

*/

(

/* ALGORITHM:
   1. compute array of all values between min and max
   2. scramble array
   3. keep first 'size' elements
*/


// initial solution
"Populating array with pattern matching: ".post;
~arr1 = {

	| size=8, min=0, max=10 |
	(min..max).scramble.keep(size);
};
~arr1.value(8, 0, 10).postln;


// using .add
"Populating array with .add(): ".post;
z = [];
~arr2 = { | size=8, min=0, max=10 |
	while ( { min < max }, { min = min + 1; z = z.add(min); });
	z.scramble.keep(size);
};
~arr2.value(8, 0, 10).postln;
)


/* Problem 3a.

Write an expression that:
   •  Generates one hundred float values between 0 and 1 rounded to the hundredth
   •  Converts those floats to the range 24-92 and rounds them to the nearest integer
   •  Removes duplicate numbers (resulting in an array with a size less than 100)
   •  Reorders the values such that they are ordered from highest to lowest
   •  Posts a multiline string with 1) the name of the results followed by the collection and 2) the size of the resulting collection
*/

(
~arr;
~genArray = {
	| size, initMin=0.0, initMax=1.0, initPrecision, finalMin, finalMax, finalPrecision=1 |
	Array.fill(size, {
		((initMax.rand.trunc(initPrecision)) // get init float values
			* (finalMax - finalMin) + finalMin).round(finalPrecision) // map to new range
	}).as(Set).as(Array) // remove duplicates
	.sort.reverse; // order from highest to lowest
};

~arr = ~genArray.value(100, 0.0, 1.0, 0.01, 24, 92);

postln("Resulting array:" ++ ~arr
	++ "\nSize: " ++ ~arr.size)
)


/* Problem 3b.

Write an expression that:
Achieves an array with 100 unique float values (between 0 and 1) rounded to the hundredth decimal point, sorted high to low using the control structure 'while'. (As above, but do not follow the prescribed steps, just acheive the result as efficiently as possible.)

*/

(  // Your code here

// using quicksort to efficiently sort resulting array
a = Array.fill(10, { |i| i.rrand(0.0, 1.0).trunc(0.01) }).scramble;
("Original array: " ++ a).postln;

// detemine partition
~partition = { | arr, low, high |
	p = arr.at(high); // pivot
	i = (low - 1); // index of smaller element
	j = low;
	while ({ j <= (high-1) }, {
		// if current element is smaller than pivot
		if (arr.at(j) < p, { i = i + 1; arr.swap(i, j) });
		j = j + 1;
	});
	arr.swap(i + 1, high);
	(i + 1);
};

// sort given array using quicksort
~quickSort = { | arr, low, high |
	if (low < high, {
		~pivot = ~partition.value(arr, low, high);
		~quickSort.value(arr, low, (~pivot-1));
		~quickSort.value(arr, (~pivot+1), high);
	}); arr;
};
~quickSort.value(a, 0, 9).postln;
("Sorted array: " ++ a).postln;

)


/*  Problem 4.

Write an expression that:
  • Uses the do Control Structure to fill an array with 5 octaves worth of a C major scale (in MIDI* numbers)
  • The numbers should start with 24 (Which is C1)

Below is an Environmental variable assigned to an Array (~array) to fill with the midi values.

~scale is assigned to a special kind of class, the Scale class.  When you iterate over ~scale you will see that it is already populated.

Expected Length: this can be coded in one-line using 4 messages (.thisIsAMessage) and 4 operations (this + thing).

Note: you will not be graded-down if your code is longer, is multiline, etc.  The above is to give you an idea of the amount of code required.

* all you need to know about MIDI for now is that MIDI numbers are integers between 0-127

*/

(
~array = [];
~scale = Scale.major;

~array = Array.fill(5, { |j|
	Array.fill(7, { |i| (~scale[i] // get scale
		+ (12 * j) + 24).asInteger; // tranform scale
	})
}).flat; // flatten array of octave values

~array.postln;
)