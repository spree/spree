/**
 * Copyright (c) 2009 Chris Leonello
 * jqPlot is currently available for use in all personal or commercial projects 
 * under both the MIT and GPL version 2.0 licenses. This means that you can 
 * choose the license that best suits your project and use it accordingly. 
 *
 * The author would appreciate an email letting him know of any substantial
 * use of jqPlot.  You can reach the author at: chris dot leonello at gmail 
 * dot com or see http://www.jqplot.com/info.php .  This is, of course, 
 * not required.
 *
 * If you are feeling kind and generous, consider supporting the project by
 * making a donation at: http://www.jqplot.com/donate.php .
 *
 * Thanks for using jqPlot!
 * 
 */
(function($) {  
    /**
     * Class: $.jqplot.DateAxisRenderer
     * A plugin for a jqPlot to render an axis as a series of date values.
     * This renderer has no options beyond those supplied by the <Axis> class.
     * It supplies it's own tick formatter, so the tickOptions.formatter option
     * should not be overridden.
     * 
     * Thanks to Ken Synder for his enhanced Date instance methods which are
     * included with this code <http://kendsnyder.com/sandbox/date/>.
     * 
     * To use this renderer, include the plugin in your source
     * > <script type="text/javascript" language="javascript" src="plugins/jqplot.dateAxisRenderer.js"></script>
     * 
     * and supply the appropriate options to your plot
     * 
     * > {axes:{xaxis:{renderer:$.jqplot.DateAxisRenderer}}}
     * 
     * Dates can be passed into the axis in almost any recognizable value and 
     * will be parsed.  They will be rendered on the axis in the format
     * specified by tickOptions.formatString.  e.g. tickOptions.formatString = '%Y-%m-%d'.
     * 
     * Accecptable format codes 
     * are:
     * 
     * > Code    Result                  Description
     * >             == Years ==
     * > %Y      2008                Four-digit year
     * > %y      08                  Two-digit year
     * >             == Months ==
     * > %m      09                  Two-digit month
     * > %#m     9                   One or two-digit month
     * > %B      September           Full month name
     * > %b      Sep                 Abbreviated month name
     * >             == Days ==
     * > %d      05                  Two-digit day of month
     * > %#d     5                   One or two-digit day of month
     * > %e      5                   One or two-digit day of month
     * > %A      Sunday              Full name of the day of the week
     * > %a      Sun                 Abbreviated name of the day of the week
     * > %w      0                   Number of the day of the week (0 = Sunday, 6 = Saturday)
     * > %o      th                  The ordinal suffix string following the day of the month
     * >             == Hours ==
     * > %H      23                  Hours in 24-hour format (two digits)
     * > %#H     3                   Hours in 24-hour integer format (one or two digits)
     * > %I      11                  Hours in 12-hour format (two digits)
     * > %#I     3                   Hours in 12-hour integer format (one or two digits)
     * > %p      PM                  AM or PM
     * >             == Minutes ==
     * > %M      09                  Minutes (two digits)
     * > %#M     9                   Minutes (one or two digits)
     * >             == Seconds ==
     * > %S      02                  Seconds (two digits)
     * > %#S     2                   Seconds (one or two digits)
     * > %s      1206567625723       Unix timestamp (Seconds past 1970-01-01 00:00:00)
     * >             == Milliseconds ==
     * > %N      008                 Milliseconds (three digits)
     * > %#N     8                   Milliseconds (one to three digits)
     * >             == Timezone ==
     * > %O      360                 difference in minutes between local time and GMT
     * > %Z      Mountain Standard Time  Name of timezone as reported by browser
     * > %G      -06:00              Hours and minutes between GMT
     * >             == Shortcuts ==
     * > %F      2008-03-26          %Y-%m-%d
     * > %T      05:06:30            %H:%M:%S
     * > %X      05:06:30            %H:%M:%S
     * > %x      03/26/08            %m/%d/%y
     * > %D      03/26/08            %m/%d/%y
     * > %#c     Wed Mar 26 15:31:00 2008  %a %b %e %H:%M:%S %Y
     * > %v      3-Sep-2008          %e-%b-%Y
     * > %R      15:31               %H:%M
     * > %r      3:31:00 PM          %I:%M:%S %p
     * >             == Characters ==
     * > %n      \n                  Newline
     * > %t      \t                  Tab
     * > %%      %                   Percent Symbol 
     */
    $.jqplot.DateAxisRenderer = function() {
        $.jqplot.LinearAxisRenderer.call(this);
    };
    
    $.jqplot.DateAxisRenderer.prototype = new $.jqplot.LinearAxisRenderer();
    $.jqplot.DateAxisRenderer.prototype.constructor = $.jqplot.DateAxisRenderer;
    
    $.jqplot.DateTickFormatter = function(format, val) {
        if (!format) {
        	format = '%Y/%m/%d';
        }
        return Date.create(val).strftime(format);
    };
    
    $.jqplot.DateAxisRenderer.prototype.init = function(options){
        // prop: tickRenderer
        // A class of a rendering engine for creating the ticks labels displayed on the plot, 
        // See <$.jqplot.AxisTickRenderer>.
        // this.tickRenderer = $.jqplot.AxisTickRenderer;
        // this.labelRenderer = $.jqplot.AxisLabelRenderer;
        this.tickOptions.formatter = $.jqplot.DateTickFormatter;
        this.daTickInterval = null;
        this._daTickInterval = null;
        $.extend(true, this, options);
        var db = this._dataBounds;
        // Go through all the series attached to this axis and find
        // the min/max bounds for this axis.
        for (var i=0; i<this._series.length; i++) {
            var s = this._series[i];
            var d = s.data;
            var pd = s._plotData;
            var sd = s._stackData;
            
            for (var j=0; j<d.length; j++) { 
                if (this.name == 'xaxis' || this.name == 'x2axis') {
                    d[j][0] = Date.create(d[j][0]).getTime();
                    pd[j][0] = Date.create(d[j][0]).getTime();
                    sd[j][0] = Date.create(d[j][0]).getTime();
                    if (d[j][0] < db.min || db.min == null) {
                    	db.min = d[j][0];
                    }
                    if (d[j][0] > db.max || db.max == null) {
                    	db.max = d[j][0];
                    }
                }              
                else {
                    d[j][1] = Date.create(d[j][1]).getTime();
                    pd[j][1] = Date.create(d[j][1]).getTime();
                    sd[j][1] = Date.create(d[j][1]).getTime();
                    if (d[j][1] < db.min || db.min == null) {
                    	db.min = d[j][1];
                    }
                    if (d[j][1] > db.max || db.max == null) {
                    	db.max = d[j][1];
                    }
                }              
            }
        }
    };
    
    // called with scope of an axis
    $.jqplot.DateAxisRenderer.prototype.reset = function() {
        this.min = this._min;
        this.max = this._max;
        this.tickInterval = this._tickInterval;
        this.numberTicks = this._numberTicks;
        this.daTickInterval = this._daTickInterval;
        // this._ticks = this.__ticks;
    };
    
    $.jqplot.DateAxisRenderer.prototype.createTicks = function() {
        // we're are operating on an axis here
        var ticks = this._ticks;
        var userTicks = this.ticks;
        var name = this.name;
        // databounds were set on axis initialization.
        var db = this._dataBounds;
        var dim, interval;
        var min, max;
        var pos1, pos2;
        var tt, i;
        
        // if we already have ticks, use them.
        // ticks must be in order of increasing value.
        
        if (userTicks.length) {
            // ticks could be 1D or 2D array of [val, val, ,,,] or [[val, label], [val, label], ...] or mixed
            for (i=0; i<userTicks.length; i++){
                var ut = userTicks[i];
                var t = new this.tickRenderer(this.tickOptions);
                if (ut.constructor == Array) {
                    t.value = Date.create(ut[0]).getTime();
                    t.label = ut[1];
                    if (!this.showTicks) {
                        t.showLabel = false;
                        t.showMark = false;
                    }
                    else if (!this.showTickMarks) {
                        t.showMark = false;
                    }
                    t.setTick(t.value, this.name);
                    this._ticks.push(t);
                }
                
                else {
                    t.value = Date.create(ut).getTime();
                    if (!this.showTicks) {
                        t.showLabel = false;
                        t.showMark = false;
                    }
                    else if (!this.showTickMarks) {
                        t.showMark = false;
                    }
                    t.setTick(t.value, this.name);
                    this._ticks.push(t);
                }
            }
            this.numberTicks = userTicks.length;
            this.min = this._ticks[0].value;
            this.max = this._ticks[this.numberTicks-1].value;
            this.daTickInterval = [(this.max - this.min) / (this.numberTicks - 1)/1000, 'seconds'];
        }
        
        // we don't have any ticks yet, let's make some!
        else {
            if (name == 'xaxis' || name == 'x2axis') {
                dim = this._plotDimensions.width;
            }
            else {
                dim = this._plotDimensions.height;
            }
            
            // if min, max and number of ticks specified, user can't specify interval.
            if (this.min != null && this.max != null && this.numberTicks != null) {
                this.tickInterval = null;
            }
            
            // if user specified a tick interval, convert to usable.
            if (this.tickInterval != null)
            {
                // if interval is a number or can be converted to one, use it.
                // Assume it is in SECONDS!!!
                if (Number(this.tickInterval)) {
                    this.daTickInterval = [Number(this.tickInterval), 'seconds'];
                }
                // else, parse out something we can build from.
                else if (typeof this.tickInterval == "string") {
                    var parts = this.tickInterval.split(' ');
                    if (parts.length == 1) {
                        this.daTickInterval = [1, parts[0]];
                    }
                    else if (parts.length == 2) {
                        this.daTickInterval = [parts[0], parts[1]];
                    }
                }
            }
        
            min = ((this.min != null) ? Date.create(this.min).getTime() : db.min);
            max = ((this.max != null) ? Date.create(this.max).getTime() : db.max);
            
            // if min and max are same, space them out a bit
            if (min == max) {
                var adj = 24*60*60*500;  // 1/2 day
                min -= adj;
                max += adj;
            }

            var range = max - min;
            var rmin, rmax;
        
            rmin = (this.min != null) ? Date.create(this.min).getTime() : min - range/2*(this.padMin - 1);
            rmax = (this.max != null) ? Date.create(this.max).getTime() : max + range/2*(this.padMax - 1);
            this.min = rmin;
            this.max = rmax;
            range = this.max - this.min;
    
            if (this.numberTicks == null){
                // if tickInterval is specified by user, we will ignore computed maximum.
                // max will be equal or greater to fit even # of ticks.
                if (this.daTickInterval != null) {
                    var nc = Date.create(this.max).diff(this.min, this.daTickInterval[1], true);
                    this.numberTicks = Math.ceil(nc/this.daTickInterval[0]) +1;
                    // this.max = Date.create(this.min).add(this.numberTicks-1, this.daTickInterval[1]).getTime();
                    this.max = Date.create(this.min).add((this.numberTicks-1) * this.daTickInterval[0], this.daTickInterval[1]).getTime();
                }
                else if (dim > 200) {
                    this.numberTicks = parseInt(3+(dim-200)/100, 10);
                }
                else {
                    this.numberTicks = 2;
                }
            }
    
            if (this.daTickInterval == null) {
            	this.daTickInterval = [range / (this.numberTicks-1)/1000, 'seconds'];
            }
            for (var i=0; i<this.numberTicks; i++){
                var min = Date.create(this.min);
                tt = min.add(i*this.daTickInterval[0], this.daTickInterval[1]).getTime();
                var t = new this.tickRenderer(this.tickOptions);
                // var t = new $.jqplot.AxisTickRenderer(this.tickOptions);
                if (!this.showTicks) {
                    t.showLabel = false;
                    t.showMark = false;
                }
                else if (!this.showTickMarks) {
                    t.showMark = false;
                }
                t.setTick(tt, this.name);
                this._ticks.push(t);
            }
        }
        if (this._daTickInterval == null) {
            this._daTickInterval = this.daTickInterval;    
        }
    };
    
    
    
    /**
     * Date instance methods
     *
     * @author Ken Snyder (ken d snyder at gmail dot com)
     * @date 2008-09-10
     * @version 2.0.2 (http://kendsnyder.com/sandbox/date/)     
     * @license Creative Commons Attribution License 3.0 (http://creativecommons.org/licenses/by/3.0/)
     *
     * @contributions Chris Leonello
     * @comment Bug fix to 12 hour time and additions to handle milliseconds and 
     * @comment 24 hour time without am/pm suffix
     *
     */
 
    // begin by creating a scope for utility variables
    
    //
    // pre-calculate the number of milliseconds in a day
    //  
    
    var day = 24 * 60 * 60 * 1000;
    //
    // function to add leading zeros
    //
    var zeroPad = function(number, digits) {
        number = String(number);
        while (number.length < digits) {
            number = '0' + number;
        }
        return number;
    };
    //
    // set up integers and functions for adding to a date or subtracting two dates
    //
    var multipliers = {
        millisecond: 1,
        second: 1000,
        minute: 60 * 1000,
        hour: 60 * 60 * 1000,
        day: day,
        week: 7 * day,
        month: {
            // add a number of months
            add: function(d, number) {
                // add any years needed (increments of 12)
                multipliers.year.add(d, Math[number > 0 ? 'floor' : 'ceil'](number / 12));
                // ensure that we properly wrap betwen December and January
                var prevMonth = d.getMonth() + (number % 12);
                if (prevMonth == 12) {
                    prevMonth = 0;
                    d.setYear(d.getFullYear() + 1);
                } else if (prevMonth == -1) {
                    prevMonth = 11;
                    d.setYear(d.getFullYear() - 1);
                }
                d.setMonth(prevMonth);
            },
            // get the number of months between two Date objects (decimal to the nearest day)
            diff: function(d1, d2) {
                // get the number of years
                var diffYears = d1.getFullYear() - d2.getFullYear();
                // get the number of remaining months
                var diffMonths = d1.getMonth() - d2.getMonth() + (diffYears * 12);
                // get the number of remaining days
                var diffDays = d1.getDate() - d2.getDate();
                // return the month difference with the days difference as a decimal
                return diffMonths + (diffDays / 30);
            }
        },
        year: {
            // add a number of years
            add: function(d, number) {
                d.setYear(d.getFullYear() + Math[number > 0 ? 'floor' : 'ceil'](number));
            },
            // get the number of years between two Date objects (decimal to the nearest day)
            diff: function(d1, d2) {
                return multipliers.month.diff(d1, d2) / 12;
            }
        }        
    };
    //
    // alias each multiplier with an 's' to allow 'year' and 'years' for example
    //
    for (var unit in multipliers) {
        if (unit.substring(unit.length - 1) != 's') { // IE will iterate newly added properties :|
            multipliers[unit + 's'] = multipliers[unit];
        }
    }
    //
    // take a date instance and a format code and return the formatted value
    //
    var format = function(d, code) {
            if (Date.prototype.strftime.formatShortcuts[code]) {
                    // process any shortcuts recursively
                    return d.strftime(Date.prototype.strftime.formatShortcuts[code]);
            } else {
                    // get the format code function and toPaddedString() argument
                    var getter = (Date.prototype.strftime.formatCodes[code] || '').split('.');
                    var nbr = d['get' + getter[0]] ? d['get' + getter[0]]() : '';
                    // run toPaddedString() if specified
                    if (getter[1]) {
                    	nbr = zeroPad(nbr, getter[1]);
                    }
                    // prepend the leading character
                    return nbr;
            }       
    };
    //
    // Add methods to Date instances
    //
    var instanceMethods = {
        //
        // Return a date one day ahead (or any other unit)
        //
        // @param string unit
        // units: year | month | day | week | hour | minute | second | millisecond
        // @return object Date
        //
        succ: function(unit) {
            return this.clone().add(1, unit);
        },
        //
        // Add an arbitrary amount to the currently stored date
        //
        // @param integer/float number      
        // @param string unit
        // @return object Date (chainable)      
        //
        add: function(number, unit) {
            var factor = multipliers[unit] || multipliers.day;
            if (typeof factor == 'number') {
                this.setTime(this.getTime() + (factor * number));
            } else {
                factor.add(this, number);
            }
            return this;
        },
        //
        // Find the difference between the current and another date
        //
        // @param string/object dateObj
        // @param string unit
        // @param boolean allowDecimal
        // @return integer/float
        //
        diff: function(dateObj, unit, allowDecimal) {
            // ensure we have a Date object
            dateObj = Date.create(dateObj);
            if (dateObj === null) {
            	return null;
            }
            // get the multiplying factor integer or factor function
            var factor = multipliers[unit] || multipliers.day;
            if (typeof factor == 'number') {
                // multiply
                var unitDiff = (this.getTime() - dateObj.getTime()) / factor;
            } else {
                // run function
                var unitDiff = factor.diff(this, dateObj);
            }
            // if decimals are not allowed, round toward zero
            return (allowDecimal ? unitDiff : Math[unitDiff > 0 ? 'floor' : 'ceil'](unitDiff));          
        },
        //
        // Convert a date to a string using traditional strftime format codes
        //
        // @param string formatStr
        // @return string
        //
        strftime: function(formatStr) {
            // default the format string to year-month-day
            var source = formatStr || '%Y-%m-%d', result = '', match;
            // replace each format code
            while (source.length > 0) {
                if (match = source.match(Date.prototype.strftime.formatCodes.matcher)) {
                    result += source.slice(0, match.index);
                    result += (match[1] || '') + format(this, match[2]);
                    source = source.slice(match.index + match[0].length);
                } else {
                    result += source;
                    source = '';
                }
            }
            return result;
        },
        //
        // Return a proper two-digit year integer
        //
        // @return integer
        //
        getShortYear: function() {
            return this.getYear() % 100;
        },
        //
        // Get the number of the current month, 1-12
        //
        // @return integer
        //
        getMonthNumber: function() {
            return this.getMonth() + 1;
        },
        //
        // Get the name of the current month
        //
        // @return string
        //
        getMonthName: function() {
            return Date.MONTHNAMES[this.getMonth()];
        },
        //
        // Get the abbreviated name of the current month
        //
        // @return string
        //
        getAbbrMonthName: function() {
            return Date.ABBR_MONTHNAMES[this.getMonth()];
        },
        //
        // Get the name of the current week day
        //
        // @return string
        //      
        getDayName: function() {
            return Date.DAYNAMES[this.getDay()];
        },
        //
        // Get the abbreviated name of the current week day
        //
        // @return string
        //      
        getAbbrDayName: function() {
            return Date.ABBR_DAYNAMES[this.getDay()];
        },
        //
        // Get the ordinal string associated with the day of the month (i.e. st, nd, rd, th)
        //
        // @return string
        //      
        getDayOrdinal: function() {
            return Date.ORDINALNAMES[this.getDate() % 10];
        },
        //
        // Get the current hour on a 12-hour scheme
        //
        // @return integer
        //
        getHours12: function() {
            var hours = this.getHours();
            return hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
        },
        //
        // Get the AM or PM for the current time
        //
        // @return string
        //
        getAmPm: function() {
            return this.getHours() >= 12 ? 'PM' : 'AM';
        },
        //
        // Get the current date as a Unix timestamp
        //
        // @return integer
        //
        getUnix: function() {
            return Math.round(this.getTime() / 1000, 0);
        },
        //
        // Get the GMT offset in hours and minutes (e.g. +06:30)
        //
        // @return string
        //
        getGmtOffset: function() {
            // divide the minutes offset by 60
            var hours = this.getTimezoneOffset() / 60;
            // decide if we are ahead of or behind GMT
            var prefix = hours < 0 ? '+' : '-';
            // remove the negative sign if any
            hours = Math.abs(hours);
            // add the +/- to the padded number of hours to : to the padded minutes
            return prefix + zeroPad(Math.floor(hours), 2) + ':' + zeroPad((hours % 1) * 60, 2);
        },
        //
        // Get the browser-reported name for the current timezone (e.g. MDT, Mountain Daylight Time)
        //
        // @return string
        //
        getTimezoneName: function() {
            var match = /(?:\((.+)\)$| ([A-Z]{3}) )/.exec(this.toString());
            return match[1] || match[2] || 'GMT' + this.getGmtOffset();
        },
        //
        // Convert the current date to an 8-digit integer (%Y%m%d)
        //
        // @return int
        //
        toYmdInt: function() {
            return (this.getFullYear() * 10000) + (this.getMonthNumber() * 100) + this.getDate();
        },  
        //
        // Create a copy of a date object
        //
        // @return object
        //       
        clone: function() {
                return new Date(this.getTime());
        }
    };
    for (var name in instanceMethods) {
        Date.prototype[name] = instanceMethods[name];
    }
    //
    // Add static methods to the date object
    //
    var staticMethods = {
        //
        // The heart of the date functionality: returns a date object if given a convertable value
        //
        // @param string/object/integer date
        // @return object Date
        //
        create: function(date) {
            // If the passed value is already a date object, return it
            if (date instanceof Date) {
            	return date;
            }
            // if (typeof date == 'number') return new Date(date * 1000);
            // If the passed value is an integer, interpret it as a javascript timestamp
            if (typeof date == 'number') {
            	return new Date(date);
            }
            // If the passed value is a string, attempt to parse it using Date.parse()
            var parsable = String(date).replace(/^\s*(.+)\s*$/, '$1'), i = 0, length = Date.create.patterns.length, pattern;
            var current = parsable;
            while (i < length) {
                ms = Date.parse(current);
                if (!isNaN(ms)) {
                	return new Date(ms);
                }
                pattern = Date.create.patterns[i];
                if (typeof pattern == 'function') {
                    obj = pattern(current);
                    if (obj instanceof Date) {
                    	return obj;
                    }
                } else {
                    current = parsable.replace(pattern[0], pattern[1]);
                }
                i++;
            }
            return NaN;
        },
        //
        // constants representing month names, day names, and ordinal names
        // (same names as Ruby Date constants)
        //
        MONTHNAMES          : 'January February March April May June July August September October November December'.split(' '),
        ABBR_MONTHNAMES : 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split(' '),
        DAYNAMES                : 'Sunday Monday Tuesday Wednesday Thursday Friday Saturday'.split(' '),
        ABBR_DAYNAMES       : 'Sun Mon Tue Wed Thu Fri Sat'.split(' '),
        ORDINALNAMES        : 'th st nd rd th th th th th th'.split(' '),
        //
        // Shortcut for full ISO-8601 date conversion
        //
        ISO: '%Y-%m-%dT%H:%M:%S.%N%G',
        //
        // Shortcut for SQL-type formatting
        //
        SQL: '%Y-%m-%d %H:%M:%S',
        //
        // Setter method for month, day, and ordinal names for i18n
        //
        // @param object newNames
        //
        daysInMonth: function(year, month) {
            if (month == 2) {
            	return new Date(year, 1, 29).getDate() == 29 ? 29 : 28;
            }
            return [undefined,31,undefined,31,30,31,30,31,31,30,31,30,31][month];
        }
    };
    for (var name in staticMethods) {
        Date[name] = staticMethods[name];
    }
    //
    // format codes for strftime
    //
    // each code must be an array where the first member is the name of a Date.prototype function
    // and optionally a second member indicating the number to pass to Number#toPaddedString()
    //
    Date.prototype.strftime.formatCodes = {
        //
        // 2-part regex matcher for format codes
        //
        // first match must be the character before the code (to account for escaping)
        // second match must be the format code character(s)
        //
        matcher: /()%(#?(%|[a-z]))/i,
        // year
        Y: 'FullYear',
        y: 'ShortYear.2',
        // month
        m: 'MonthNumber.2',
        '#m': 'MonthNumber',
        B: 'MonthName',
        b: 'AbbrMonthName',
        // day
        d: 'Date.2',
        '#d': 'Date',
        e: 'Date',
        A: 'DayName',
        a: 'AbbrDayName',
        w: 'Day',
        o: 'DayOrdinal',
        // hours
        H: 'Hours.2',
        '#H': 'Hours',
        I: 'Hours12.2',
        '#I': 'Hours12',
        p: 'AmPm',
        // minutes
        M: 'Minutes.2',
        '#M': 'Minutes',
        // seconds
        S: 'Seconds.2',
        '#S': 'Seconds',
        s: 'Unix',
        // milliseconds
        N: 'Milliseconds.3',
        '#N': 'Milliseconds',
        // timezone
        O: 'TimezoneOffset',
        Z: 'TimezoneName',
        G: 'GmtOffset'  
    };
    //
    // shortcuts that will be translated into their longer version
    //
    // be sure that format shortcuts do not refer to themselves: this will cause an infinite loop
    //
    Date.prototype.strftime.formatShortcuts = {
        // date
        F: '%Y-%m-%d',
        // time
        T: '%H:%M:%S',
        X: '%H:%M:%S',
        // local format date
        x: '%m/%d/%y',
        D: '%m/%d/%y',
        // local format extended
        '#c': '%a %b %e %H:%M:%S %Y',
        // local format short
        v: '%e-%b-%Y',
        R: '%H:%M',
        r: '%I:%M:%S %p',
        // tab and newline
        t: '\t',
        n: '\n',
        '%': '%'
    };
    //
    // A list of conversion patterns (array arguments sent directly to gsub)
    // Add, remove or splice a patterns to customize date parsing ability
    //
    Date.create.patterns = [
        [/-/g, '/'], // US-style time with dashes => Parsable US-style time
        [/st|nd|rd|th/g, ''], // remove st, nd, rd and th        
        [/(3[01]|[0-2]\d)\s*\.\s*(1[0-2]|0\d)\s*\.\s*([1-9]\d{3})/, '$2/$1/$3'], // World time => Parsable US-style time
        [/([1-9]\d{3})\s*-\s*(1[0-2]|0\d)\s*-\s*(3[01]|[0-2]\d)/, '$2/$3/$1'], // ISO-style time => Parsable US-style time
        function(str) { // 12-hour or 24 hour time with milliseconds
            // var match = str.match(/^(?:(.+)\s+)?([1-9]|1[012])(?:\s*\:\s*(\d\d))?(?:\s*\:\s*(\d\d))?\s*(am|pm)\s*$/i);
            var match = str.match(/^(?:(.+)\s+)?([012]?\d)(?:\s*\:\s*(\d\d))?(?:\s*\:\s*(\d\d(\.\d*)?))?\s*(am|pm)?\s*$/i);
            //                   opt. date      hour       opt. minute     opt. second       opt. msec   opt. am or pm
            if (match) {
                if (match[1]) {
                    var d = Date.create(match[1]);
                    if (isNaN(d)) {
                    	return;
                    }
                } else {
                    var d = new Date();
                    d.setMilliseconds(0);
                }
                var hour = parseFloat(match[2]);
                if (match[6]) {
                    hour = match[6].toLowerCase() == 'am' ? (hour == 12 ? 0 : hour) : (hour == 12 ? 12 : hour + 12);
                }
                d.setHours(hour, parseInt(match[3] || 0, 10), parseInt(match[4] || 0, 10), ((parseFloat(match[5] || 0)) || 0)*1000);
                return d;
            }
            else {
                return str;
            }
        },
        function(str) { // ISO timestamp with time zone.
            var match = str.match(/^(?:(.+))[T|\s+]([012]\d)(?:\:(\d\d))(?:\:(\d\d))(?:\.\d+)([\+\-]\d\d\:\d\d)$/i);
            if (match) {
                if (match[1]) {
                    var d = Date.create(match[1]);
                    if (isNaN(d)) {
                    	return;
                    }
                } else {
                    var d = new Date();
                    d.setMilliseconds(0);
                }
                var hour = parseFloat(match[2]);
                d.setHours(hour, parseInt(match[3], 10), parseInt(match[4], 10), parseFloat(match[5])*1000);
                return d;
            }
            else {
                    return str;
            }
        },
        function(str) {
            var match = str.match(/^([0-3]?\d)\s*[-\/.\s]{1}\s*([a-zA-Z]{3,9})\s*[-\/.\s]{1}\s*([0-3]?\d)$/);
            if (match) {
                var d = new Date();
                var y = parseFloat(String(d.getFullYear()).slice(2,4));
                var cent = parseInt(String(d.getFullYear())/100, 10)*100;
                var centoffset = 1;
                var m1 = parseFloat(match[1]);
                var m3 = parseFloat(match[3]);
                var ny, nd, nm;
                if (m1 > 31) { // first number is a year
                    nd = match[3];
                    if (m1 < y+centoffset) { // if less than 1 year out, assume it is this century.
                        ny = cent + m1;
                    }
                    else {
                        ny = cent - 100 + m1;
                    }
                }
                
                else { // last number is the year
                    nd = match[1];
                    if (m3 < y+centoffset) { // if less than 1 year out, assume it is this century.
                        ny = cent + m3;
                    }
                    else {
                        ny = cent - 100 + m3;
                    }
                }
                
                var nm = $.inArray(match[2], Date.ABBR_MONTHNAMES);
                
                if (nm == -1) {
                    nm = $.inArray(match[2], Date.MONTHNAMES);
                }
            
                d.setFullYear(ny, nm, nd);
                d.setHours(0,0,0,0);
                return d;
            }
            
            else {
                return str;
            }
        }        
    ];
    
    if ($.jqplot.config.debug) {
    	$.date = Date.create;
    }
   
})(jQuery);

