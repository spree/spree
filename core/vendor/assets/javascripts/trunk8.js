/**!
 * trunk8 v1.2.3
 * https://github.com/rviscomi/trunk8
 * 
 * Copyright 2012 Rick Viscomi
 * Released under the MIT License.
 * 
 * Date: September 9, 2012
 */

(function ($) {
	var methods,
		utils,
		SIDES = {
			/* cen...ter */
			center: 'center',
			/* ...left */
			left: 'left',
			/* right... */
			right: 'right'
		},
		WIDTH = {
			auto: 'auto'
		},
		settings = {
			fill: '&hellip;',
			lines: 1,
			side: SIDES.right,
			tooltip: true,
			width: WIDTH.auto
		};

	function truncate() {
		var width = settings.width,
			side = settings.side,
			fill = settings.fill,
			line_height = utils.getLineHeight(this) * settings.lines,
			str = this.data('trunk8') || this.text(),
			length = str.length,
			max_bite = '',
			lower, upper,
			bite_size,
			bite;
		
		/* Reset the field to the original string. */
		this.html(str).data('trunk8', str);

		if (width === WIDTH.auto) {
			/* Assuming there is no "overflow: hidden". */
			if (this.height() <= line_height) {
				/* Text is already at the optimal trunkage. */
				return;
			}

			/* Binary search technique for finding the optimal trunkage. */
			/* Find the maximum bite without overflowing. */
			lower = 0;
			upper = length - 1;

			while (lower <= upper) {
				bite_size = lower + ((upper - lower) >> 1);
				
				bite = utils.eatStr(str, side, length - bite_size, fill);
				
				this.html(bite);

				/* Check for overflow. */
				if (this.height() > line_height) {
					upper = bite_size - 1;
				}
				else {
					lower = bite_size + 1;

					/* Save the bigger bite. */
					max_bite = (max_bite.length > bite.length) ? max_bite : bite;
				}
			}

			/* Reset the content to eliminate possible existing scroll bars. */
			this.html('');
			
			/* Display the biggest bite. */
			this.html(max_bite);
			
			if (settings.tooltip) {
				this.attr('title', str);
			}
		}
		else if (!isNaN(width)) {
			bite_size = length - width;

			bite = utils.eatStr(str, side, bite_size, fill);

			this.html(bite);
			
			if (settings.tooltip) {
				this.attr('title', str);
			}
		}
		else {
			$.error('Invalid width "' + width + '".');
		}
	}

	methods = {
		init: function (options) {
			settings = $.extend(settings, options);
			
			return this.each(function () {
				truncate.call($(this));
			});
		},

		/** Updates the text value of the elements while maintaining truncation. */
		update: function (new_string) {
			return this.each(function () {
				/* Update text. */
				if (new_string) {
					$(this).data('trunk8', new_string);
				}

				/* Truncate accordingly. */
				truncate.call($(this));
			});
		},
		
		revert: function () {
			return this.each(function () {
				/* Get original text. */
				var text = $(this).data('trunk8');
				
				/* Revert element to original text. */
				$(this).html(text);
			});
		},

		/** Returns this instance's settings object. NOT CHAINABLE. */
		getSettings: function () {
			return settings;
		}
	};

	utils = {
		/** Replaces [bite_size] [side]-most chars in [str] with [fill]. */
		eatStr: function (str, side, bite_size, fill) {
		    var length = str.length,
		    	key = utils.eatStr.generateKey.apply(null, arguments),
		        half_length,
		        half_bite_size;

	        /* If the result is already in the cache, return it. */
	        if (utils.eatStr.cache[key]) {
				return utils.eatStr.cache[key];
	        }
	        
			/* Common error handling. */
		    if ((typeof str !== 'string') || (length === 0)) {
		    	$.error('Invalid source string "' + str + '".');
		    }
		    if ((bite_size < 0) || (bite_size > length)) {
		    	$.error('Invalid bite size "' + bite_size + '".');
		    }
		    else if (bite_size === 0) {
			    /* No bite should show no truncation. */
				return str;
		    }
		    if (typeof (fill + '') !== 'string') {
				$.error('Fill unable to be converted to a string.');
		    }

			/* Compute the result, store it in the cache, and return it. */
		    switch (side) {
		        case SIDES.right:
			        /* str... */
		            return utils.eatStr.cache[key] =
			            	$.trim(str.substr(0, length - bite_size)) + fill;
		            
		        case SIDES.left:
			        /* ...str */
		            return utils.eatStr.cache[key] =
			            	fill + $.trim(str.substr(bite_size));
		            
		        case SIDES.center:
			        /* Bit-shift to the right by one === Math.floor(x / 2) */
		            half_length = length >> 1; // halve the length
		            half_bite_size = bite_size >> 1; // halve the bite_size

			        /* st...r */
		            return utils.eatStr.cache[key] =
			            	$.trim(utils.eatStr(str.substr(0, length - half_length), SIDES.right, bite_size - half_bite_size, '')) +
		            		fill +
		            		$.trim(utils.eatStr(str.substr(length - half_length), SIDES.left, half_bite_size, ''));
		            
		        default:
		        	$.error('Invalid side "' + side + '".');
		    }
		},
		
		getLineHeight: function (elem) {
			var html = $(elem).html(),
				wrapper_id = 'line-height-test',
				line_height;
			
			/* Set the content to a small single character and wrap. */
			$(elem).html('i').wrap('<div id="' + wrapper_id + '" />');
			
			/* Calculate the line height by measuring the wrapper.*/
			line_height = $('#' + wrapper_id).innerHeight();
			
			/* Remove the wrapper and reset the content. */
			$(elem).html(html).unwrap();
			
			return line_height;
		}
	};

	utils.eatStr.cache = {};
	utils.eatStr.generateKey = function () {
		return Array.prototype.join.call(arguments, '');
	};
	
	$.fn.trunk8 = function (method) {
		if (methods[method]) {
			return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
		}
		else if (typeof method === 'object' || !method) {
			return methods.init.apply(this, arguments);
		}
		else {
			$.error('Method ' + method + ' does not exist on jQuery.trunk8');
		}
	};
})(jQuery);