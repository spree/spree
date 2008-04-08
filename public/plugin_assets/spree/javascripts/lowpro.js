LowPro = {};
LowPro.Version = '0.1';

// Adapted from DOM Ready extension by Dan Webb
// http://www.vivabit.com/bollocks/2006/06/21/a-dom-ready-extension-for-prototype
// which was based on work by Matthias Miller, Dean Edwards and John Resig
//
// Usage:
//
// Event.onReady(callbackFunction);
Object.extend(Event, {
  _domReady : function() {
    if (arguments.callee.done) return;
    arguments.callee.done = true;

    if (Event._timer)  clearInterval(Event._timer);
    
    Event._readyCallbacks.each(function(f) { f() });
    Event._readyCallbacks = null;
    
  },
  onReady : function(f) {
    if (!this._readyCallbacks) {
      var domReady = this._domReady;
      
      if (domReady.done) return f();
      
      if (document.addEventListener)
        document.addEventListener("DOMContentLoaded", domReady, false);
        
        /*@cc_on @*/
        /*@if (@_win32)
            document.write("<script id=__ie_onload defer src=javascript:void(0)><\/script>");
            document.getElementById("__ie_onload").onreadystatechange = function() {
                if (this.readyState == "complete") { domReady(); }
            };
        /*@end @*/
        
        if (/WebKit/i.test(navigator.userAgent)) { 
          this._timer = setInterval(function() {
            if (/loaded|complete/.test(document.readyState)) domReady(); 
          }, 10);
        }
        
        Event.observe(window, 'load', domReady);
        Event._readyCallbacks =  [];
    }
    Event._readyCallbacks.push(f);
  }
});

if (!Element.addMethods) 
  Element.addMethods = function(o) { Object.extend(Element.Methods, o) };

// Extend Element with observe and stopObserving.
Element.addMethods({
  observe : function(el, event, callback) {
    Event.observe(el, event, callback);
  },
  stopObserving : function(el, event, callback) {
    Event.stopObserving(el, event, callback);
  }
});

// Replace out existing event observe code with Dean Edwards' addEvent
// http://dean.edwards.name/weblog/2005/10/add-event/
Object.extend(Event, {
  observe : function(el, type, func) {
    el = $(el);
    if (!func.$$guid) func.$$guid = Event._guid++;
  	if (!el.events) el.events = {};
  	var handlers = el.events[type];
  	if (!handlers) {
  		handlers = el.events[type] = {};
  		if (el["on" + type]) {
  			handlers[0] = el["on" + type];
  		}
  	}
  	handlers[func.$$guid] = func;
  	el["on" + type] = Event._handleEvent;
  	
  	 if (!Event.observers) Event.observers = [];
  	 Event.observers.push([el, name, func, false]);
	},
	stopObserving : function(el, type, func) {
    if (el.events && el.events[type]) delete el.events[type][func.$$guid];
  },
  _handleEvent : function(e) {
    var returnValue = true;
    e = e || Event._fixEvent(window.event);
    var handlers = this.events[e.type], el = $(this);
    for (var i in handlers) {
    	el.$$handleEvent = handlers[i];
    	if (el.$$handleEvent(e) === false) returnValue = false;
    }
  	return returnValue;
  },
  _fixEvent : function(e) {
    e.preventDefault = Event._preventDefault;
    e.stopPropagation = Event._stopPropagation;
    return e;
  },
  _preventDefault : function() { this.returnValue = false },
  _stopPropagation : function() { this.cancelBubble = true },
  _guid : 1
});

// Allows you to trigger an event element.  
Object.extend(Event, {
  trigger : function(element, event, fakeEvent) {
    element = $(element);
    fakeEvent = fakeEvent || { type :  event };
    this.observers.each(function(cache) {
      if (cache[0] == element && cache[1] == event)
        cache[2].call(element, fakeEvent);
    });
  }
});

// Based on event:Selectors by Justin Palmer
// http://encytemedia.com/event-selectors/
//
// Usage:
//
// Event.addBehavior({
//      "selector:event" : function(event) { /* event handler.  this refers to the element. */ },
//      "selector" : function() { /* runs function on dom ready.  this refers to the element. */ }
//      ...
// });
//
// Multiple calls will add to exisiting rules.  Event.addBehavior.reassignAfterAjax and
// Event.addBehavior.autoTrigger can be adjusted to needs.
Event.addBehavior = function(rules) {
  var ab = this.addBehavior;
  Object.extend(ab.rules, rules);
  
  if (ab.autoTrigger) {
    this.onReady(ab.load.bind(ab));
  }
  
  Ajax.Responders.register({
    onComplete : function() { 
      if (Event.addBehavior.reassignAfterAjax) 
        setTimeout(function() { ab.load() }, 10);
    }
  });
  
};

Object.extend(Event.addBehavior, {
  rules : {}, cache : [],
  reassignAfterAjax : true,
  autoTrigger : true,
  
  load : function() {
    this.unload();
    for (var selector in this.rules) {
      var observer = this.rules[selector];
      var sels = selector.split(',');
      sels.each(function(sel) {
        var parts = sel.split(/:(?=[a-z]+$)/), css = parts[0], event = parts[1];
        $$(css).each(function(element) {
          if (event) {
            $(element).observe(event, observer);
            Event.addBehavior.cache.push([element, event, observer]);
          } else {
            if (!element.$$assigned || !element.$$assigned.include(observer)) {
              if (observer.attach) observer.attach(element);
              else observer.call($(element));
              element.$$assigned = element.$$assigned || [];
              element.$$assigned.push(observer);
            }
          }
        });
      });
    }
  },
  
  unload : function() {
    this.cache.each(function(c) {
      Event.stopObserving.apply(Event, c);
    });
  }
  
});

Event.observe(window, 'unload', Event.addBehavior.unload.bind(Event.addBehavior));

// Behaviors can be bound to elements to provide an object orientated way of controlling elements
// and their behavior.  Use Behavior.create() to make a new behavior class then use attach() to
// glue it to an element.  Each element then gets it's own instance of the behavior and any
// methods called onxxx are bound to the relevent event.
// 
// Usage:
// 
// var MyBehavior = Behavior.create({
//   onmouseover : function() { this.element.addClassName('bong') } 
// });

// Event.addBehavior({ 'a.rollover' : MyBehavior });
Behavior = {
  create : function(members) {
    var behavior = Class.create();
    behavior.prototype.initialize = Prototype.K;
    Object.extend(behavior.prototype, members);
    Object.extend(behavior, Behavior.ClassMethods);
    return behavior;
  },
  ClassMethods : {
    attach : function(element) {
      var bound = new this;
      bound.element = $(element);
      this._bindEvents(bound);
      return bound;
    },
    _bindEvents : function(bound) {
      for (var member in bound)
        if (member.match(/^on(.+)/) && typeof bound[member] == 'function')
          bound.element.observe(RegExp.$1, bound[member].bindAsEventListener(bound));
    }
  }
};


// Original code by Sylvian Zimmer
// http://www.sylvainzimmer.com/index.php/archives/2006/06/25/speeding-up-prototypes-selector/
// Optimises execution speed of the $$ function.  Rewritten for readability by Justin Palmer.
// 
// Turn off optimisation with LowPro.optimize$$ = false;
LowPro.SelectorLite = Class.create();
LowPro.SelectorLite.prototype = {
  initialize: function(selectors) {
    this.results = []; 
    this.selectors = []; 
    this.index = 0;
    
    for(var i = selectors.length -1; i >= 0; i--) {
      var params = { tag: '*', id: null, classes: [] };
      var selector = selectors[i];
      var needle = selector.length - 1;
      
      do {
        var id = selector.lastIndexOf("#");
        var klass = selector.lastIndexOf(".");
        var cursor = Math.max(id, klass);
        
        if(cursor == -1) params.tag = selector.toUpperCase();
        else if(id == -1 || klass == cursor) params.classes.push(selector.substring(klass + 1))
        else if(!params.id) params.id = selector.substring(id + 1);
        
        selector = selector.substring(0, cursor);
      } while(cursor > 0);
      this.selectors[i] = params;
    }
    
  },
  
  get: function(root) {
    this.findElements(root || document, this.index == (this.selectors.length - 1));
    return this.results;
  },
  
  findElements: function(parent, descendant) {
    var selector = this.selectors[this.index], results = [], element;
    if(selector.id) {
      element = $(selector.id);
      if(element && (selector.tag == '*' || element.tagName == selector.tag) && 
        (element.childOf(parent))) {
        results = [element];
      }
    } else {
      results = $A(parent.getElementsByTagName(selector.tag));
    }
    
    if(selector.classes.length == 1) {
      results = results.select(function(target) {
       return $(target).hasClassName(selector.classes[0]);
      });
    } else if(selector.classes.length > 1) {
      results = results.select(function(target) {
        var klasses = $(target).classNames();
        return selector.classes.all(function(klass) {
          return klasses.include(klass);
        });
      });
    }
    
    if(descendant) {
      this.results = this.results.concat(results);
    } else {
      ++this.index;
      results.each(function(target) {
        this.findElements(target, this.index == (this.selectors.length - 1));
      }.bind(this));
    }
  }
}

LowPro.$$old=$$;
LowPro.optimize$$ = true;

function $$(a,b) {
  if (LowPro.optimize$$ == false || b || a.indexOf("[")>=0) 
    return LowPro.$$old.apply(this, arguments);
  return new LowPro.SelectorLite(a.split(/\s+/)).get();
}

