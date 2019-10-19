+ SimpleMIDIFile {
	patternize { |instrument, amp = 0.2, useTempo = true|
		var thisFile;
		instrument = ( instrument ? 'default' ).asCollection; // use default instrument unless otherwise specified

		// determine timeMode
		if(useTempo) {
			if(timeMode == 'seconds')
				{ thisFile = this }
				{ thisFile = this.copy.timeMode_( 'seconds' ); };
		} {
			if(timeMode == 'ticks')
				{ thisFile = this }
				{ thisFile = this.copy.timeMode_( 'ticks' ); };
		};

		// return a pattern
		 ^Ppar(
			({ |tr|
				var sustainEvents, deltaTimes;
				sustainEvents = thisFile.noteSustainEvents( nil, tr );
				if( sustainEvents.size > 0 )
					{
					sustainEvents = sustainEvents.flop;
					if( useTempo ) {
						deltaTimes = sustainEvents[1].differentiate;
					} {
						deltaTimes = (sustainEvents[1] / (division*2)).differentiate;
						sustainEvents[6] = sustainEvents[6] / (division*2);
					};
					Pbind(
						\instrument, instrument.wrapAt( tr + 1 ),
						\dur, Pseq( deltaTimes ++ [0], 1 ),
						\chan, Pseq( [0] ++ sustainEvents[3], 1 ),
						\midinote, Pseq( [\rest] ++ sustainEvents[4], 1 ),
						\amp, Pseq( [0] ++ ( sustainEvents[5] / 127 ) * amp, 1 ),
						\sustain, Pseq( [0] ++ sustainEvents[6], 1 )
						)
					}
					{ nil }
				}!this.tracks).select({ |item| item.notNil })
			);
		}
}