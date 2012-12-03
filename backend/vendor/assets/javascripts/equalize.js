/**
 * equalize.js
 * Author & copyright (c) 2012: Tim Svensen
 * Dual MIT & GPL license
 *
 * Page: http://tsvensen.github.com/equalize.js
 * Repo: https://github.com/tsvensen/equalize.js/
 *
 * The jQuery plugin for equalizing the height or width of elements.
 *
 * Equalize will accept any of the jQuery Dimension methods:
 *   height, outerHeight, innerHeight,
 *   width, outerWidth, innerWidth.
 *
 * EXAMPLE
 * $('.parent').equalize(); // defaults to 'height'
 * $('.parent').equalize('width'); // equalize the widths
 */
(function($, window, document, undefined) {

  $.fn.equalize = function(equalize) {
    var $containers = this, // this is the jQuery object
        equalize    = equalize || 'height',
        type        = (equalize.indexOf('eight') > 0) ? 'height' : 'width';

    if (!$.isFunction($.fn[equalize])) { return false; }

    return $containers.each(function() {
      var $children = $(this).children(),
          max = 0; // reset for each container

      $children.each(function() {
        var value = $(this)[equalize]();  // call height(), outerHeight(), etc.
        if (value > max) { max = value; } // update max
      });

      $children.css(type, max +'px'); // add CSS to children
    });
  };

}(jQuery, window, document));
