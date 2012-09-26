/*	jQuery.flexMenu
	Author: Ryan DeBeasi (352 Media Group) - http://www.352media.com/
	Description: If a list is too long for all items to fit on one line, display a popup menu instead. 
	Dependencies: jQuery, Modernizr (optional). Without Modernizr, the menu can only be shown on click (not hover). */
(function ($) {
	var $flexParents = $(''), // A collection of all elements on which flexMenu has been called.
		resizeTimeout;
	// When the page is resized, adjust the flexMenus.
	function adjustFlexMenu() {
		$flexParents.flexMenu({'undo': true }).flexMenu();
	}
	$(window).resize(function () {
		clearTimeout(resizeTimeout);
	    resizeTimeout = setTimeout(adjustFlexMenu, 200);
	});
	$.fn.flexMenu = function (options) {
		var s = $.extend({
			'threshold'	: 2,					// [integer] If there are this many items or fewer in the list, we will not display a "View More" link and will instead let the list break to the next line. This is useful in cases where adding a "view more" link would actually cause more things to break  to the next line.
			'cutoff' : 2,						// [integer] If there is space for this many or fewer items outside our "more" popup, just move everything into the more menu. In that case, also use linkTextAll and linkTitleAll instead of linkText and linkTitle. To disable this feature, just set this value to 0.
			'linkText' : 'More',				// [string] What text should we display on the "view more" link?
			'linkTitle' : 'View More',			// [string] What should the title of the "view more" button be?
			'linkTextAll' : 'Menu',				// [string] If we hit the cutoff, what text should we display on the "view more" link?
			'linkTitleAll' : 'Open/Close Menu',	// [string] If we hit the cutoff, what should the title of the "view more" button be?
			'showOnHover' : true,				// [boolean] Should we we show the menu on hover? If not, we'll require a click. If we're on a touch device - or if Modernizr is not available - we'll ignore this setting and only show the menu on click. The reason for this is that touch devices emulate hover events in unpredictable ways, causing some taps to do nothing.
			'popupAbsolute' : true,				// [boolean] Should we absolutely position the popup? Usually this is a good idea. That way, the popup can appear over other content and spill outside a parent that has overflow: hidden set. If you want to do something different from this in CSS, just set this option to false.
			'undo' : false						// [boolean] Move the list items back to where they were before, and remove the "View More" link.
		}, options);
		return this.each(function () {
			var $this = $(this),
				$firstItem = $this.find('li:first-child'),
				$lastItem = $this.find('li:last-child'),
				numItems = $this.find('li').length,
				firstItemTop = Math.floor($firstItem.offset().top),
				firstItemHeight = Math.floor($firstItem.height()),
				$lastChild,
				keepLooking,
				$moreItem,
				$moreLink,
				numToRemove,
				allInPopup = false,
				$menu,
				i;
			function needsMenu($itemOfInterest) {
				var result = (Math.ceil($itemOfInterest.offset().top) >= (firstItemTop + firstItemHeight)) ? true : false;
				// Values may be calculated from em and give us something other than round numbers. Browsers may round these inconsistently. So, let's round numbers to make it easier to trigger flexMenu.
				return result;
			}
			$flexParents = $flexParents.add($this);
			if (needsMenu($lastItem) && numItems > s.threshold && !s.undo && $this.is(':visible')) {
				var $popup = $('<ul class="flexMenu-popup" style="display:none;' + ((s.popupAbsolute) ? ' position: absolute;' : '') + '"></ul>'),
					// Move all list items after the first to this new popup ul
					firstItemOffset = $firstItem.offset().top;
				for (i = numItems; i > 1; i--) {
					// Find all of the list items that have been pushed below the first item. Put those items into the popup menu. Put one additional item into the popup menu to cover situations where the last item is shorter than the "more" text.
					$lastChild = $this.find('li:last-child');
					keepLooking = (needsMenu($lastChild));
					$lastChild.appendTo($popup);
					// If there only a few items left in the navigation bar, move them all to the popup menu.
					if ((i - 1) <= s.cutoff) { // We've removed the ith item, so i - 1 gives us the number of items remaining.
						$($this.children().get().reverse()).appendTo($popup);
					 	allInPopup = true;
					 	break;
					}

					if (!keepLooking) {
						break;
					}
				}
				if (allInPopup) {
					$this.append('<li class="flexMenu-viewMore flexMenu-allInPopup"><a href="#" title="' + s.linkTitleAll + '">' + s.linkTextAll + '</a></li>');
				} else {
					$this.append('<li class="flexMenu-viewMore"><a href="#" title="' + s.linkTitle + '">' + s.linkText + '</a></li>');
				}
				
				$moreItem = $this.find('li.flexMenu-viewMore');
				/// Check to see whether the more link has been pushed down. This might happen if the link immediately before it is especially wide.
				if (needsMenu($moreItem)) {
					$this.find('li:nth-last-child(2)').appendTo($popup);
				}
				// Our popup menu is currently in reverse order. Let's fix that.
				$popup.children().each(function (i, li) {$popup.prepend(li); });
				$moreItem.append($popup);
				$moreLink = $this.find('li.flexMenu-viewMore > a');
				$moreItem.click(function (e) {
					$popup.toggle();
					$(this).toggleClass('active'); // Using 'this' because toggling the class of $moreItem would sometimes toggle the wrong more link's class, or not toggle at all.
					e.preventDefault();
				});
				if (s.showOnHover && (typeof Modernizr !== 'undefined') && !Modernizr.touch) { // If requireClick is false AND touch is unsupported, then show the menu on hover. If Modernizr is not available, assume that touch is unsupported. Through the magic of lazy evaluation, we can check for Modernizr and start using it in the same if statement. Reversing the order of these variables would produce an error.
					$moreItem.hover(
						function () {
							$popup.show();
							$(this).addClass('active');
						},
						function () {
							$popup.hide();
							$(this).removeClass('active');
						}
					);
				}
			} else if (s.undo && $this.find('ul.flexMenu-popup')) {
				$menu = $this.find('ul.flexMenu-popup');
				numToRemove = $menu.find('li').length;
				for (i = 1; i <= numToRemove; i++) {
					$menu.find('li:first-child').appendTo($this);
				}
				$menu.remove();
				$this.find('li.flexMenu-viewMore').remove();
			}
		});
	};
})(jQuery);