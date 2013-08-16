/**!
 * trunk8 v1.3.1
 * https://github.com/rviscomi/trunk8
 *
 * Copyright 2012 Rick Viscomi
 * Released under the MIT License.
 *
 * Date: September 26, 2012
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
    };

  function trunk8(element) {
    this.$element = $(element);
    this.original_text = this.$element.html();
    this.settings = $.extend({}, $.fn.trunk8.defaults);
  }

  trunk8.prototype.updateSettings = function (options) {
    this.settings = $.extend(this.settings, options);
  };

  function stripHTML(html) {
    var tmp = document.createElement("DIV");
    tmp.innerHTML = html;
    return tmp.textContent || tmp.innerText;
  }

  function getHtmlArr(str) {
    /* Builds an array of strings and designated */
    /* HTML tags around them. */
    if (stripHTML(str) === str) {
      return str.split(/\s/g);
    }
    var allResults = [],
      reg = /<([a-z]+)([^<]*)(?:>(.*?(?!<\1>)*)<\/\1>|\s+\/>)(['.?!,]*)|((?:[^<>\s])+['.?!,]*\w?|<br\s?\/?>)/ig,
      outArr = reg.exec(str),
      lastI,
      ind;
    while (outArr && lastI !== reg.lastIndex) {
      lastI = reg.lastIndex;
      if (outArr[5]) {
        allResults.push(outArr[5]);
      } else if (outArr[1]) {
        allResults.push({
          tag: outArr[1],
          attribs: outArr[2],
          content: outArr[3],
          after: outArr[4]
        });
      }
      outArr = reg.exec(str);
    }
    for (ind = 0; ind < allResults.length; ind++) {
      if (typeof allResults[ind] !== 'string' && allResults[ind].content) {
        allResults[ind].content = getHtmlArr(allResults[ind].content);
      }
    }
    return allResults;
  }

  function rebuildHtmlFromBite(bite, htmlObject, fill) {
    // Take the processed bite after binary-search
    // truncated and re-build the original HTML
    // tags around the processed string.
    bite = bite.replace(fill, '');

    var biteHelper = function (contentArr, tagInfo) {
      var retStr = '',
        content,
        biteContent,
        biteLength,
        i;
      for (i = 0; i < contentArr.length; i++) {
        content = contentArr[i];
        biteLength = $.trim(bite).split(' ').length;
        if ($.trim(bite).length) {
          if (typeof content === 'string') {
            if (!/<br\s*\/?>/.test(content)) {
              if (biteLength === 1 && $.trim(bite).length <= content.length) {
                content = bite;
                // We want the fill to go inside of the last HTML
                // element if the element is a container.
                if (tagInfo === 'p' || tagInfo === 'div') {
                  content += fill;
                }
                bite = '';
              } else {
                bite = bite.replace(content, '');
              }
            }
            retStr += $.trim(content) + ((i === contentArr.length - 1 || biteLength <= 1) ? '' : ' ');
          } else {
            biteContent = biteHelper(content.content, content.tag);
            if (content.after) {
              bite = bite.replace(content.after, '');
            }
            if (biteContent) {
              if (!content.after) {
                content.after = ' ';
              }
              retStr += '<' + content.tag + content.attribs + '>' + biteContent + '</' + content.tag + '>' + content.after;
            }
          }
        }
      }
      return retStr;
    },
      htmlResults = biteHelper(htmlObject);

    // Add fill if doesn't exist. This will place it outside the HTML elements.
    if (htmlResults.slice(htmlResults.length - fill.length) === fill) {
      htmlResults += fill;
    }

    return htmlResults;
  }

  function truncate() {
    var data = this.data('trunk8'),
      settings = data.settings,
      width = settings.width,
      side = settings.side,
      fill = settings.fill,
      parseHTML = settings.parseHTML,
      line_height = utils.getLineHeight(this) * settings.lines,
      str = data.original_text,
      length = str.length,
      max_bite = '',
      lower, upper,
      bite_size,
      bite,
      text,
      htmlObject;

    /* Reset the field to the original string. */
    this.html(str);
    text = this.text();

    /* If string has HTML and parse HTML is set, build */
    /* the data struct to house the tags */
    if (parseHTML && stripHTML(str) !== str) {
      htmlObject = getHtmlArr(str);
      str = stripHTML(str);
      length = str.length;
    }

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

        if (parseHTML && htmlObject) {
          bite = rebuildHtmlFromBite(bite, htmlObject, fill);
        }

        this.html(bite);

        /* Check for overflow. */
        if (this.height() > line_height) {
          upper = bite_size - 1;
        } else {
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
        this.attr('title', text);
      }
    } else if (!isNaN(width)) {
      bite_size = length - width;

      bite = utils.eatStr(str, side, bite_size, fill);

      this.html(bite);

      if (settings.tooltip) {
        this.attr('title', str);
      }
    } else {
      $.error('Invalid width "' + width + '".');
    }
  }

  methods = {
    init: function (options) {
      return this.each(function () {
        var $this = $(this),
          data = $this.data('trunk8');

        if (!data) {
          $this.data('trunk8', (data = new trunk8(this)));
        }

        data.updateSettings(options);

        truncate.call($this);
      });
    },

    /** Updates the text value of the elements while maintaining truncation. */
    update: function (new_string) {
      return this.each(function () {
        var $this = $(this);

        /* Update text. */
        if (new_string) {
          $this.data('trunk8').original_text = new_string;
        }

        /* Truncate accordingly. */
        truncate.call($this);
      });
    },

    revert: function () {
      return this.each(function () {
        /* Get original text. */
        var text = $(this).data('trunk8').original_text;

        /* Revert element to original text. */
        $(this).html(text);
      });
    },

    /** Returns this instance's settings object. NOT CHAINABLE. */
    getSettings: function () {
      return $(this.get(0)).data('trunk8').settings;
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
      } else if (bite_size === 0) {
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
        return utils.eatStr.cache[key] = $.trim(str.substr(0, length - bite_size)) + fill;

      case SIDES.left:
        /* ...str */
        return utils.eatStr.cache[key] = fill + $.trim(str.substr(bite_size));

      case SIDES.center:
        /* Bit-shift to the right by one === Math.floor(x / 2) */
        half_length = length >> 1; // halve the length
        half_bite_size = bite_size >> 1; // halve the bite_size

        /* st...r */
        return utils.eatStr.cache[key] = $.trim(utils.eatStr(str.substr(0, length - half_length), SIDES.right, bite_size - half_bite_size, '')) + fill + $.trim(utils.eatStr(str.substr(length - half_length), SIDES.left, half_bite_size, ''));

      default:
        $.error('Invalid side "' + side + '".');
      }
    },

    getLineHeight: function (elem) {
      var floats = $(elem).css('float');
      if (floats !== 'none') {
        $(elem).css('float', 'none');
      }
      var pos = $(elem).css('position');
      if (pos === 'absolute') {
        $(elem).css('position', 'static');
      }

      var html = $(elem).html(),
        wrapper_id = 'line-height-test',
        line_height;

      /* Set the content to a small single character and wrap. */
      $(elem).html('i').wrap('<div id="' + wrapper_id + '" />');

      /* Calculate the line height by measuring the wrapper.*/
      line_height = $('#' + wrapper_id).innerHeight();

      /* Remove the wrapper and reset the content. */
      $(elem).html(html).css({
        'float': floats,
        'position': pos
      }).unwrap();

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
    } else if (typeof method === 'object' || !method) {
      return methods.init.apply(this, arguments);
    } else {
      $.error('Method ' + method + ' does not exist on jQuery.trunk8');
    }
  };

  /* Default trunk8 settings. */
  $.fn.trunk8.defaults = {
    fill: '&hellip;',
    lines: 1,
    side: SIDES.right,
    tooltip: true,
    width: WIDTH.auto,
    parseHTML: false
  };
})(jQuery);