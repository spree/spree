(function($) {
    function stopEvent(e) {
        e.preventDefault();
        e.stopPropagation();
        e.stopped = true;
    }

    function getFirstDifferencePos(newS, oldS) {
        var boundary = Math.min(newS.length, oldS.length);
        for (var index = 0; index < boundary; ++index)
            if (newS[index] != oldS[index]) return index;
        return boundary;
    }

    var AutoComplete = function(element, update, url, options) {
        var autocomplete        = this;

        this.element            = element;
        this.url                = url;
        this.update             = update;
        this.hasFocus           = false;
        this.changed            = false;
        this.active             = false;
        this.index              = 0;
        this.entryCount         = 0;
        this.oldElementValue    = this.element.value;
        this.observer           = null;
        this.options = $.extend({
            paramName: this.element.name,
            type: 'GET',
            tokens: [],
            frequency: 0.4,
            minChars: 1,
            onShow: function(element, update) {
                if (!update.style.position || update.style.position == 'absolute') {
                    var position = $(element).position();
                    $(update).css({
                       position: 'absolute',
                       left: position.left + 'px',
                       top: $(element).outerHeight() + position.top + 'px',
                       width: $(element).outerWidth() + 'px'
                    });
                }
                $(update).fadeIn();
            },
            onHide: function(element, update) {
                $(update).fadeOut();
            }
        }, options);

        if (typeof(this.options.tokens) == 'string') {
            this.options.tokens = new Array(this.options.tokens);
        }
        if (!$.inArray("\n", this.options.tokens)) {
            this.options.tokens.push("\n");
        }

        $(this.update).hide();
        $(this.element).attr('autocomplete', 'off')
        .blur(function(e) { autocomplete.onBlur(e); })
        .keypress(function(e) { autocomplete.onKeyPress(e); });
    }
    $.extend(AutoComplete.prototype, {
        show: function() {
            if ($(this.update).not(':visible')) this.options.onShow(this.element, this.update);
        },
        hide: function() {
            this.stopIndicator();
            if ($(this.update).is(':visible')) this.options.onHide(this.element, this.update);
        },
        startIndicator: function() {
            if (this.options.indicator) $('#' + this.options.indicator).show();
        },
        stopIndicator: function() {
            if (this.options.indicator) $('#' + this.options.indicator).hide();
        },
        onKeyPress: function(e) {
            var autocomplete = this;

            if (this.active) {
                switch (e.keyCode) {
                    case 9:     // tab
                    case 13:    // return
                        this.selectEntry();
                        stopEvent(e);
                    case 27:    // esc
                        this.hide();
                        this.active = false;
                        stopEvent(e);
                    case 37:    // left
                    case 39:    // right
                        return;
                    case 38:    // up
                        this.markPrevious();
                        this.render();
                        stopEvent(e);
                        return;
                    case 40:    // down
                        this.markNext();
                        this.render();
                        stopEvent(e);
                        return;
                }
            }
            else if (e.keyCode == 9 || e.keyCode == 13) return;

            this.changed = this.hasFocus = true;
            if (this.observer) clearTimeout(this.observer);
            this.observer = setTimeout(function() { autocomplete.onObserverEvent(); }, this.frequency * 1000);
        },
        activate: function() {
            this.changed = false;
            this.hasFocus = true;
            this.getUpdatedChoices();
        },
        onHover: function(e) {
            if (this.index != e.target.autocompleteIndex) {
                this.index = e.target.autocompleteIndex;
                this.render();
            }
            stopEvent(e);
        },
        onClick: function(e) {
            this.index = e.target.autocompleteIndex;
            this.selectEntry();
            this.hide();
        },
        onBlur: function(e) {
            var autocomplete = this;
            setTimeout(function() { autocomplete.hide(); }, 250);
            this.active = this.hasFocus = false;
        },
        render: function() {
            if (this.entryCount > 0) {
                for (var i = 0; i < this.entryCount; ++i) {
                    $(this.getEntry(i))[this.index == i ? 'addClass' : 'removeClass']('selected');
                }
                if (this.hasFocus) {
                    this.show();
                    this.active = true;
                }
            }
            else {
                this.active = false;
                this.hide();
            }
        },
        markPrevious: function() {
            if (this.index > 0) --this.index;
            else this.index = this.entryCount - 1;
        },
        markNext: function() {
            if (this.index < this.entryCount - 1) ++this.index;
            else this.index = 0;
        },
        getEntry: function(i) {
            return $(this.update.firstChild).children('li').get(i);
        },
        getCurrentEntry: function() {
            return this.getEntry(this.index);
        },
        selectEntry: function() {
            this.active = false;
            this.updateElement(this.getCurrentEntry());
        },
        updateElement: function(element) {
            if (this.options.updateElement) {
                this.options.updateElement(element);
                return;
            }

            var value = $.trim(this.options.select ?
                $('.' + this.options.select, element).text() :
                $(element).text());

            var bounds = this.getTokenBounds();
            if (bounds[0] != -1) {
                var newValue = this.element.value.substr(0, bounds[0]);
                var whitespace = this.element.value.substr(bounds[0]).match(/^\s+/);
                if (whitespace) newValue += whitespace[0];
                this.element.value = newValue + value + this.element.value.substr(bounds[1]);
            }
            else {
                this.element.value = value;
            }

            this.oldElementValue = $(this.element).focus().val();

            if (this.options.afterUpdateElement) this.options.afterUpdateElement(this.element, element);
        },
        updateChoices: function(choices) {
            if (!this.changed && this.hasFocus) {
                $(this.update).html($.trim(choices));
                var i = 0, autocomplete = this;
                this.entryCount = $(this.update.firstChild).children('li').each(function() {
                    this.autocompleteIndex = i++;
                    autocomplete.addObservers(this);
                }).length;
            }

            this.stopIndicator();
            this.index = 0;

            if (this.entryCount == 1 && this.options.autoSelect) {
                this.selectEntry();
                this.hide();
            }
            else {
                this.render();
            }
        },
        addObservers: function(element) {
            var autocomplete = this;
            $(element)
                .mouseover(function(e) { autocomplete.onHover(e); })
                .click(function(e) { autocomplete.onClick(e); });
        },
        onObserverEvent: function() {
            this.changed = false;
            this.tokenBounds = null;
            if (this.getToken().length >= this.options.minChars) {
                this.getUpdatedChoices();
            }
            else {
                this.active = false;
                this.hide();
            }
            this.oldElementValue = this.element.value;
        },
        getToken: function() {
            var bounds = this.getTokenBounds();
            return $.trim(this.element.value.substring(bounds[0], bounds[1]));
        },
        getTokenBounds: function() {
            if (null != this.tokenBounds) return this.tokenBounds;
            var value = $.trim(this.element.value);
            if (!value.length) return [-1, 0];
            var diff = getFirstDifferencePos(value, this.oldElementValue);
            var offset = (diff == this.oldElementValue.length ? 1 : 0);
            var prevTokenPos = -1, nextTokenPos = value.length;
            for (var tp = null, index = 0, l = this.options.tokens.length; index < l; ++index) {
                tp = value.lastIndexOf(this.options.tokens[index], diff + offset - 1);
                if (tp > prevTokenPos) prevTokenPos = tp;
                tp = value.indexOf(this.options.tokens[index], diff + offset);
                if (-1 != tp && tp < nextTokenPos) nextTokenPos = tp;
            }
            return (this.tokenBounds = [prevTokenPos + 1, nextTokenPos]);
        },
        getUpdatedChoices: function() {
            this.startIndicator();

            var autocomplete = this, entry = encodeURIComponent(this.options.paramName) + '=' + encodeURIComponent(this.getToken());
            this.options.data = this.options.callback ? this.options.callback(this.element, entry) : entry;

            if (this.options.defaultParams) this.options.data += '&' + this.options.defaultParams;
            var ajaxOptions = $.extend({}, this.options, {
                url: this.url,
                success: function(data, status) {
                    autocomplete.updateChoices(data);
                }
            });
            $.ajax(ajaxOptions);
        }
    });

    $.fn.autocomplete = function(options) {
        var update = $('#' + options.update).get(0), url = options.url;
        options.update = options.url = undefined;
        this.filter(':text').each(function() {
            new AutoComplete(this, update, url, options);
        });
        return this;
    }
})(jQuery);