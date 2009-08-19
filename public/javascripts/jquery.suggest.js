	
	/*
	 *	jquery.suggest 1.1 - 2007-08-06
	 *	
	 *	Uses code and techniques from following libraries:
	 *	1. http://www.dyve.net/jquery/?autocomplete
	 *	2. http://dev.jquery.com/browser/trunk/plugins/interface/iautocompleter.js	
	 *
	 *	All the new stuff written by Peter Vulgaris (www.vulgarisoip.com)	
	 *	Feel free to do whatever you want with this file
	 *
	 */
	
	(function($) {
        var defaults = {
          delay: 100,
          resultsClass: 'jquery-suggestion-results',
          selectClass: 'jquery-suggestion-select',
          matchClass: 'jquery-suggestion-match',
          minchars: 2,
          onSelect: function($input, $result) {
              $input.val($result.data('autocomplete:value'));
          },
          maxCacheSize: 65536,
          source: '',
          method: 'get',
          dataType: 'json',
          params: '',
          queryParam: 'q'
        };

		$.suggest = function(input, options) {
            options = $.extend({}, defaults, options);

			var $input = $(input).attr("autocomplete", "off");
			var $results = $('<ul></ul>');

			var timeout = false;		// hold timeout ID for suggestion results to appear	
			var prevLength = 0;			// last recorded length of $input.val()
			var cache = [];				// cache MRU list
			var cacheSize = 0;			// size of cache in chars (bytes?)
			
			$results.addClass(options.resultsClass).appendTo('body').hide();

			resetPosition();
			$(window)
				.load(resetPosition)		// just in case user is changing size of page while loading
				.resize(resetPosition);

			$input.blur(function() {
				setTimeout(function() { $results.hide() }, 200);
			});
			
			// help IE users if possible
			if ($results.bgiframe) $results.bgiframe();

			// I really hate browser detection, but I don't see any other way
			if ($.browser.mozilla)
				$input.keypress(processKey);	// onkeypress repeats arrow keys in Mozilla/Opera
			else
				$input.keydown(processKey);		// onkeydown repeats arrow keys in IE/Safari

			function resetPosition() {
				// requires jquery.dimension plugin
				var offset = $input.offset();
				$results.css({
					top: (offset.top + input.offsetHeight) + 'px',
					left: offset.left + 'px'
				});
			}
			
			function processKey(e) {
				// handling up/down/escape requires results to be visible
				// handling enter/tab requires that AND a result to be selected
				if ((/27$|38$|40$/.test(e.keyCode) && $results.is(':visible')) ||
					(/^13$|^9$/.test(e.keyCode) && getCurrentResult())) {
		            
		            if (e.preventDefault)
		                e.preventDefault();
					if (e.stopPropagation)
		                e.stopPropagation();

					e.cancelBubble = true;
					e.returnValue = false;
				
					switch(e.keyCode) {
						case 38: // up
							prevResult();
							break;
						case 40: // down
							nextResult();
							break;
						case 9:  // tab
						case 13: // return
							selectCurrentResult();
							break;
						case 27: //	escape
							$results.hide();
							break;
					}
				}
                else if ($input.val().length != prevLength) {
					if (timeout) 
						clearTimeout(timeout);
					timeout = setTimeout(suggest, options.delay);
					prevLength = $input.val().length;
				}			
			}
			
			function suggest() {
				var q = $.trim($input.val());

				if (q.length >= options.minchars) {
					cached = checkCache(q);
					if (cached) {
						displayItems(cached['items']);
					}
                    else {
                        var params = options.queryParam + '=' + q + (options.params.length ? '&' + options.params : '');
                        $.ajax({
                           type: options.method,
                           url: options.source,
                           dataType: options.dataType,
                           data: params,
                           success: function(data) {
                               $results.hide();

                               displayItems(data);
                               addToCache(q, data);
                           },
                           error: function(xmlhttp, text) {
                               $results.hide();
                               alert(text);
                           }
                        });
					}
				}
                else {
					$results.hide();
				}
			}
			
			function checkCache(q) {
				for (var i = 0; i < cache.length; i++)
					if (cache[i]['q'] == q) {
						cache.unshift(cache.splice(i, 1)[0]);
						return cache[0];
					}
				return false;
			}
			
			function addToCache(q, items) {
                var size = 0;
                $.each(items, function() {
                   ++size;
                });

				while (cache.length && (cacheSize + size > options.maxCacheSize)) {
					var cached = cache.pop();
					cacheSize -= cached['size'];
				}
				
				cache.push({
					q: q,
					size: size,
					items: items
				});
				cacheSize += size;
			}
			
			function displayItems(items) {
				if (!items)
					return;
				var empty = true;
                $results.empty();
				$.each(items, function(value, display) {
                    var $item = $('<li></li>').html(display).data('autocomplete:value', value);
                    $results.append($item);
                    empty = false;
                });

                if (empty) {
					$results.hide();
					return;
				}

                resetPosition();
				$results
                    .width($input.width())
                    .show()
					.children('li')
					.mouseover(function() {
						$results.children('li').removeClass(options.selectClass);
						$(this).addClass(options.selectClass);
					})
					.click(function(e) {
						e.preventDefault(); 
						e.stopPropagation();
						selectCurrentResult();
					});		
			}
			
			function parseTxt(txt, q) {
				var items = [];
				var tokens = txt.split(options.delimiter);
				
				// parse returned data for non-empty items
				for (var i = 0; i < tokens.length; i++) {
					var token = $.trim(tokens[i]);
					if (token) {
						token = token.replace(
							new RegExp(q, 'ig'), 
							function(q) { return '<span class="' + options.matchClass + '">' + q + '</span>' }
							);
						items[items.length] = token;
					}
				}
				return items;
			}
			
			function getCurrentResult() {
				if (!$results.is(':visible'))
					return false;
			
				var $currentResult = $results.children('li.' + options.selectClass);
				if (!$currentResult.length)
					$currentResult = false;
					
				return $currentResult;
			}
			
			function selectCurrentResult() {
				$currentResult = getCurrentResult();
			
				if ($currentResult) {
                    options.onSelect.call(this, $input, $currentResult);
					$results.hide();
				}
			}
			
			function nextResult() {
				$currentResult = getCurrentResult();
			
				if ($currentResult)
					$currentResult
						.removeClass(options.selectClass)
						.next()
							.addClass(options.selectClass);
				else
					$results.children('li:first-child').addClass(options.selectClass);
			}
			
			function prevResult() {
				$currentResult = getCurrentResult();
			
				if ($currentResult)
					$currentResult
						.removeClass(options.selectClass)
						.prev()
							.addClass(options.selectClass);
				else
					$results.children('li:last-child').addClass(options.selectClass);
			}
		}
		
		$.fn.suggest = function(source, options) {
			if (!source)
				return;
            options.source = source;
			this.each(function() {
				new $.suggest(this, options);
			});
			return this;
		};
	})(jQuery);
	
