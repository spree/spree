/*
 * jsTree 0.9.9a
 * http://jstree.com/
 *
 * Copyright (c) 2009 Ivan Bozhanov (vakata.com)
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Date: 2009-10-06
 *
 */

(function($) {
	// jQuery plugin
	$.tree = {
		datastores	: { },
		plugins		: { },
		defaults	: {
			data	: {
				async	: false,		// Are async requests used to load open_branch contents
				type	: "html",		// One of included datastores
				opts	: { method: "GET", url: false } // Options passed to datastore
			},
			selected	: false,		// FALSE or STRING or ARRAY
			opened		: [],			// ARRAY OF INITIALLY OPENED NODES
			languages	: [],			// ARRAY of string values (which will be used as CSS classes - so they must be valid)
			ui		: {
				dots		: true,		// BOOL - dots or no dots
				animation	: 0,		// INT - duration of open/close animations in miliseconds
				scroll_spd	: 4,
				theme_path	: false,	// Path to the theme CSS file - if set to false and theme_name is not false - will lookup jstree-path-here/themes/theme-name-here/style.css
				theme_name	: "default",// if set to false no theme will be loaded
				selected_parent_close	: "select_parent", // false, "deselect", "select_parent"
				selected_delete			: "select_previous" // false, "select_previous"
			},
			types	: {
				"default" : {
					clickable	: true, // can be function
					renameable	: true, // can be function
					deletable	: true, // can be function
					creatable	: true, // can be function
					draggable	: true, // can be function
					max_children	: -1, // -1 - not set, 0 - no children, 1 - one child, etc // can be function
					max_depth		: -1, // -1 - not set, 0 - no children, 1 - one level of children, etc // can be function
					valid_children	: "all", // all, none, array of values // can be function
					icon : {
						image : false,
						position : false
					}
				}
			},
			rules	: {
				multiple	: false,	// FALSE | CTRL | ON - multiple selection off/ with or without holding Ctrl
				multitree	: "none",	// all, none, array of tree IDs to accept from
				type_attr	: "rel",	// STRING attribute name (where is the type stored as string)
				createat	: "bottom",	// STRING (top or bottom) new nodes get inserted at top or bottom
				drag_copy	: "ctrl",	// FALSE | CTRL | ON - drag to copy off/ with or without holding Ctrl
				drag_button	: "left",	// left, right or both
				use_max_children	: true,
				use_max_depth		: true,

				max_children: -1,
				max_depth	: -1,
				valid_children : "all"
			},
			lang : {
				new_node	: "New folder",
				loading		: "Loading ..."
			},
			callback	: {
				beforechange: function(NODE,TREE_OBJ) { return true },
				beforeopen	: function(NODE,TREE_OBJ) { return true },
				beforeclose	: function(NODE,TREE_OBJ) { return true },
				beforemove	: function(NODE,REF_NODE,TYPE,TREE_OBJ) { return true }, 
				beforecreate: function(NODE,REF_NODE,TYPE,TREE_OBJ) { return true }, 
				beforerename: function(NODE,LANG,TREE_OBJ) { return true }, 
				beforedelete: function(NODE,TREE_OBJ) { return true }, 
				beforedata	: function(NODE,TREE_OBJ) { return { id : $(NODE).attr("id") || 0 } }, // PARAMETERS PASSED TO SERVER
				ondata		: function(DATA,TREE_OBJ) { return DATA; },		// modify data before parsing it
				onparse		: function(STR,TREE_OBJ) { return STR; },		// modify string before visualizing it
				onhover		: function(NODE,TREE_OBJ) { },					// node hovered
				onselect	: function(NODE,TREE_OBJ) { },					// node selected
				ondeselect	: function(NODE,TREE_OBJ) { },					// node deselected
				onchange	: function(NODE,TREE_OBJ) { },					// focus changed
				onrename	: function(NODE,TREE_OBJ,RB) { },				// node renamed
				onmove		: function(NODE,REF_NODE,TYPE,TREE_OBJ,RB) { },	// move completed
				oncopy		: function(NODE,REF_NODE,TYPE,TREE_OBJ,RB) { },	// copy completed
				oncreate	: function(NODE,REF_NODE,TYPE,TREE_OBJ,RB) { },	// node created
				ondelete	: function(NODE,TREE_OBJ,RB) { },				// node deleted
				onopen		: function(NODE,TREE_OBJ) { },					// node opened
				onopen_all	: function(TREE_OBJ) { },						// all nodes opened
				onclose_all	: function(TREE_OBJ) { },						// all nodes closed
				onclose		: function(NODE,TREE_OBJ) { },					// node closed
				error		: function(TEXT,TREE_OBJ) { },					// error occured
				ondblclk	: function(NODE,TREE_OBJ) { TREE_OBJ.toggle_branch.call(TREE_OBJ, NODE); TREE_OBJ.select_branch.call(TREE_OBJ, NODE); },
				onrgtclk	: function(NODE,TREE_OBJ,EV) { },				// right click - to prevent use: EV.preventDefault(); EV.stopPropagation(); return false
				onload		: function(TREE_OBJ) { },
				oninit		: function(TREE_OBJ) { },
				onfocus		: function(TREE_OBJ) { },
				ondestroy	: function(TREE_OBJ) { },
				onsearch	: function(NODES, TREE_OBJ) { NODES.addClass("search"); },
				ondrop		: function(NODE,REF_NODE,TYPE,TREE_OBJ) { },
				check		: function(RULE,NODE,VALUE,TREE_OBJ) { return VALUE; },
				check_move	: function(NODE,REF_NODE,TYPE,TREE_OBJ) { return true; }
			},
			plugins : { }
		},

		create		: function () { return new tree_component(); },
		focused		: function () { return tree_component.inst[tree_component.focused]; },
		reference	: function (obj) { 
			var o = $(obj); 
			if(!o.size()) o = $("#" + obj);
			if(!o.size()) return null; 
			o = (o.is(".tree")) ? o.attr("id") : o.parents(".tree:eq(0)").attr("id"); 
			return tree_component.inst[o] || null; 
		},
		rollback	: function (data) {
			for(var i in data) {
				if(!data.hasOwnProperty(i)) continue;
				var tmp = tree_component.inst[i];
				var lock = !tmp.locked;

				// if not locked - lock the tree
				if(lock) tmp.lock(true);
				// Cancel ongoing rename
				tmp.inp = false;
				tmp.container.html(data[i].html).find(".dragged").removeClass("dragged").end().find(".hover").removeClass("hover");

				if(data[i].selected) {
					tmp.selected = $("#" + data[i].selected);
					tmp.selected_arr = [];
					tmp.container
						.find("a.clicked").each( function () {
							tmp.selected_arr.push(tmp.get_node(this));
						});
				}
				// if this function set the lock - unlock
				if(lock) tmp.lock(false);

				delete lock;
				delete tmp;
			}
		},
		drop_mode	: function (opts) {
			opts = $.extend(opts, { show : false, type : "default", str : "Foreign node" });
			tree_component.drag_drop.foreign	= true;
			tree_component.drag_drop.isdown		= true;
			tree_component.drag_drop.moving		= true;
			tree_component.drag_drop.appended	= false;
			tree_component.drag_drop.f_type		= opts.type;
			tree_component.drag_drop.f_data		= opts;


			if(!opts.show) {
				tree_component.drag_drop.drag_help	= false;
				tree_component.drag_drop.drag_node	= false;
			}
			else {
				tree_component.drag_drop.drag_help	= $("<div id='jstree-dragged' class='tree tree-default'><ul><li class='last dragged foreign'><a href='#'><ins>&nbsp;</ins>" + opts.str + "</a></li></ul></div>");
				tree_component.drag_drop.drag_node	= tree_component.drag_drop.drag_help.find("li:eq(0)");
			}
			if($.tree.drag_start !== false) $.tree.drag_start.call(null, false);
		},
		drag_start	: false,
		drag		: false,
		drag_end	: false
	};
	$.fn.tree = function (opts) {
		return this.each(function() {
			var conf = $.extend({},opts);
			if(tree_component.inst && tree_component.inst[$(this).attr('id')]) tree_component.inst[$(this).attr('id')].destroy();
			if(conf !== false) new tree_component().init(this, conf);
		});
	};

	// core
	function tree_component () {
		return {
			cntr : ++tree_component.cntr,
			settings : $.extend({},$.tree.defaults),

			init : function(elem, conf) {
				var _this = this;
				this.container = $(elem);
				if(this.container.size == 0) return false;
				tree_component.inst[this.cntr] = this;
				if(!this.container.attr("id")) this.container.attr("id","jstree_" + this.cntr); 
				tree_component.inst[this.container.attr("id")] = tree_component.inst[this.cntr];
				tree_component.focused = this.cntr;
				this.settings = $.extend(true, {}, this.settings, conf);

				// DEAL WITH LANGUAGE VERSIONS
				if(this.settings.languages && this.settings.languages.length) {
					this.current_lang = this.settings.languages[0];
					var st = false;
					var id = "#" + this.container.attr("id");
					for(var ln = 0; ln < this.settings.languages.length; ln++) {
						st = tree_component.add_css(id + " ." + this.settings.languages[ln]);
						if(st !== false) st.style.display = (this.settings.languages[ln] == this.current_lang) ? "" : "none";
					}
				}
				else this.current_lang = false;
				// THEMES
				this.container.addClass("tree");
				if(this.settings.ui.theme_name !== false) {
					if(this.settings.ui.theme_path === false) {
						$("script").each(function () { 
							if(this.src.toString().match(/jquery\.tree.*?js$/)) { _this.settings.ui.theme_path = this.src.toString().replace(/jquery\.tree.*?js$/, "") + "themes/" + _this.settings.ui.theme_name + "/style.css"; return false; }
						});
					}
					if(this.settings.ui.theme_path != "" && $.inArray(this.settings.ui.theme_path, tree_component.themes) == -1) {
						tree_component.add_sheet({ url : this.settings.ui.theme_path });
						tree_component.themes.push(this.settings.ui.theme_path);
					}
					this.container.addClass("tree-" + this.settings.ui.theme_name);
				}
				// TYPE ICONS
				var type_icons = "";
				for(var t in this.settings.types) {
					if(!this.settings.types.hasOwnProperty(t)) continue;
					if(!this.settings.types[t].icon) continue;
					if( this.settings.types[t].icon.image || this.settings.types[t].icon.position) {
						if(t == "default")  type_icons += "#" + this.container.attr("id") + " li > a ins { ";
						else type_icons += "#" + this.container.attr("id") + " li[rel=" + t + "] > a ins { ";
						if(this.settings.types[t].icon.image) type_icons += " background-image:url(" + this.settings.types[t].icon.image + "); ";
						if(this.settings.types[t].icon.position) type_icons += " background-position:" + this.settings.types[t].icon.position + "; ";
						type_icons += "} ";
					}
				}
				if(type_icons != "") tree_component.add_sheet({ str : type_icons });

				if(this.settings.rules.multiple) this.selected_arr = [];
				this.offset = false;
				this.hovered = false;
				this.locked = false;

				if(tree_component.drag_drop.marker === false) tree_component.drag_drop.marker = $("<div>").attr({ id : "jstree-marker" }).hide().appendTo("body");
				this.callback("oninit", [this]);
				this.refresh();
				this.attach_events();
				this.focus();
			},
			refresh : function (obj) {
				if(this.locked) return this.error("LOCKED");
				var _this = this;
				if(obj && !this.settings.data.async) obj = false;
				this.is_partial_refresh = obj ? true : false;

				// SAVE OPENED
				this.opened = Array();
				if(this.settings.opened != false) {
					$.each(this.settings.opened, function (i, item) {
						if(this.replace(/^#/,"").length > 0) { _this.opened.push("#" + this.replace(/^#/,"")); }
					});
					this.settings.opened = false;
				}
				else {
					this.container.find("li.open").each(function (i) { if(this.id) { _this.opened.push("#" + this.id); } });
				}

				// SAVE SELECTED
				if(this.selected) {
					this.settings.selected = Array();
					if(obj) {
						$(obj).find("li:has(a.clicked)").each(function () {
							if(this.id) _this.settings.selected.push("#" + this.id);
						});
					}
					else {
						if(this.selected_arr) {
							$.each(this.selected_arr, function () {
								if(this.attr("id")) _this.settings.selected.push("#" + this.attr("id"));
							});
						}
						else {
							if(this.selected.attr("id")) this.settings.selected.push("#" + this.selected.attr("id"));
						}
					}
				}
				else if(this.settings.selected !== false) {
					var tmp = Array();
					if((typeof this.settings.selected).toLowerCase() == "object") {
						$.each(this.settings.selected, function () {
							if(this.replace(/^#/,"").length > 0) tmp.push("#" + this.replace(/^#/,""));
						});
					}
					else {
						if(this.settings.selected.replace(/^#/,"").length > 0) tmp.push("#" + this.settings.selected.replace(/^#/,""));
					}
					this.settings.selected = tmp;
				}

				if(obj && this.settings.data.async) {
					this.opened = Array();
					obj = this.get_node(obj);
					obj.find("li.open").each(function (i) { _this.opened.push("#" + this.id); });
					if(obj.hasClass("open")) obj.removeClass("open").addClass("closed");
					if(obj.hasClass("leaf")) obj.removeClass("leaf");
					obj.children("ul:eq(0)").html("");
					return this.open_branch(obj, true, function () { _this.reselect.apply(_this); });
				}

				var _this = this;
				var _datastore = new $.tree.datastores[this.settings.data.type]();
				if(this.container.children("ul").size() == 0) {
					this.container.html("<ul class='ltr' style='direction:ltr;'><li class='last'><a class='loading' href='#'><ins>&nbsp;</ins>" + (this.settings.lang.loading || "Loading ...") + "</a></li></ul>");
				}
				_datastore.load(this.callback("beforedata",[false,this]),this,this.settings.data.opts,function(data) {
					data = _this.callback("ondata",[data, _this]);
					_datastore.parse(data,_this,_this.settings.data.opts,function(str) {
						str = _this.callback("onparse", [str, _this]);
						_this.container.empty().append($("<ul class='ltr'>").html(str));
						_this.container.find("li:last-child").addClass("last").end().find("li:has(ul)").not(".open").addClass("closed");
						_this.container.find("li").not(".open").not(".closed").addClass("leaf");
						_this.reselect();
					});
				});
			},
			reselect : function (is_callback) {
				var _this = this;

				if(!is_callback)	this.cl_count = 0;
				else				this.cl_count --;
				// REOPEN BRANCHES
				if(this.opened && this.opened.length) {
					var opn = false;
					for(var j = 0; this.opened && j < this.opened.length; j++) {
						if(this.settings.data.async) {
							var tmp = this.get_node(this.opened[j]);
							if(tmp.size() && tmp.hasClass("closed") > 0) {
								opn = true;
								var tmp = this.opened[j].toString().replace('/','\\/');
								delete this.opened[j];
								this.open_branch(tmp, true, function () { _this.reselect.apply(_this, [true]); } );
								this.cl_count ++;
							}
						}
						else this.open_branch(this.opened[j], true);
					}
					if(this.settings.data.async && opn) return;
					if(this.cl_count > 0) return;
					delete this.opened;
				} 
				if(this.cl_count > 0) return;

				// DOTS and RIGHT TO LEFT
				this.container.css("direction","ltr").children("ul:eq(0)").addClass("ltr");
				if(this.settings.ui.dots == false)	this.container.children("ul:eq(0)").addClass("no_dots");

				// REPOSITION SCROLL
				if(this.scrtop) {
					this.container.scrollTop(_this.scrtop);
					delete this.scrtop;
				}
				// RESELECT PREVIOUSLY SELECTED
				if(this.settings.selected !== false) {
					$.each(this.settings.selected, function (i) {
						if(_this.is_partial_refresh)	_this.select_branch($(_this.settings.selected[i].toString().replace('/','\\/'), _this.container), (_this.settings.rules.multiple !== false) );
						else							_this.select_branch($(_this.settings.selected[i].toString().replace('/','\\/'), _this.container), (_this.settings.rules.multiple !== false && i > 0) );
					});
					this.settings.selected = false;
				}
				this.callback("onload", [_this]);
			},

			get : function (obj, format, opts) {
				if(!format) format = this.settings.data.type;
				if(!opts) opts = this.settings.data.opts;
				return new $.tree.datastores[format]().get(obj, this, opts);
			},

			attach_events : function () {
				var _this = this;

				this.container
					.bind("mousedown.jstree", function (event) {
						if(tree_component.drag_drop.isdown) {
							tree_component.drag_drop.move_type = false;
							event.preventDefault();
							event.stopPropagation();
							event.stopImmediatePropagation();
							return false;
						}
					})
					.bind("mouseup.jstree", function (event) {
						setTimeout( function() { _this.focus.apply(_this); }, 5);
					})
					.bind("click.jstree", function (event) { 
						//event.stopPropagation(); 
						return true;
					});
				$("#" + this.container.attr("id") + " li")
					.live("click", function(event) { // WHEN CLICK IS ON THE ARROW
						if(event.target.tagName != "LI") return true;
						_this.off_height();
						if(event.pageY - $(event.target).offset().top > _this.li_height) return true;
						_this.toggle_branch.apply(_this, [event.target]);
						event.stopPropagation();
						return false;
					});
				$("#" + this.container.attr("id") + " li a")
					.live("click.jstree", function (event) { // WHEN CLICK IS ON THE TEXT OR ICON
						if(event.which && event.which == 3) return true;
						if(_this.locked) {
							event.preventDefault(); 
							event.target.blur();
							return _this.error("LOCKED");
						}
						_this.select_branch.apply(_this, [event.target, event.ctrlKey || _this.settings.rules.multiple == "on"]);
						if(_this.inp) { _this.inp.blur(); }
						event.preventDefault(); 
						event.target.blur();
						return false;
					})
					.live("dblclick.jstree", function (event) { // WHEN DOUBLECLICK ON TEXT OR ICON
						if(_this.locked) {
							event.preventDefault(); 
							event.stopPropagation();
							event.target.blur();
							return _this.error("LOCKED");
						}
						_this.callback("ondblclk", [_this.get_node(event.target).get(0), _this]);
						event.preventDefault(); 
						event.stopPropagation();
						event.target.blur();
					})
					.live("contextmenu.jstree", function (event) {
						if(_this.locked) {
							event.target.blur();
							return _this.error("LOCKED");
						}
						return _this.callback("onrgtclk", [_this.get_node(event.target).get(0), _this, event]);
					})
					.live("mouseover.jstree", function (event) {
						if(_this.locked) {
							event.preventDefault();
							event.stopPropagation();
							return _this.error("LOCKED");
						}
						if(_this.hovered !== false && (event.target.tagName == "A" || event.target.tagName == "INS")) {
							_this.hovered.children("a").removeClass("hover");
							_this.hovered = false;
						}
						_this.callback("onhover",[_this.get_node(event.target).get(0), _this]);
					})
					.live("mousedown.jstree", function (event) {
						if(_this.settings.rules.drag_button == "left" && event.which && event.which != 1)	return true;
						if(_this.settings.rules.drag_button == "right" && event.which && event.which != 3)	return true;
						_this.focus.apply(_this);
						if(_this.locked) return _this.error("LOCKED");
						// SELECT LIST ITEM NODE
						var obj = _this.get_node(event.target);
						// IF ITEM IS DRAGGABLE
						if(_this.settings.rules.multiple != false && _this.selected_arr.length > 1 && obj.children("a:eq(0)").hasClass("clicked")) {
							var counter = 0;
							for(var i in _this.selected_arr) {
								if(!_this.selected_arr.hasOwnProperty(i)) continue;
								if(_this.check("draggable", _this.selected_arr[i])) {
									_this.selected_arr[i].addClass("dragged");
									tree_component.drag_drop.origin_tree = _this;
									counter ++;
								}
							}
							if(counter > 0) {
								if(_this.check("draggable", obj))	tree_component.drag_drop.drag_node = obj;
								else								tree_component.drag_drop.drag_node = _this.container.find("li.dragged:eq(0)");
								tree_component.drag_drop.isdown		= true;
								tree_component.drag_drop.drag_help	= $("<div id='jstree-dragged' class='tree " + ( _this.settings.ui.theme_name != "" ? " tree-" + _this.settings.ui.theme_name : "" ) + "' />").append("<ul class='" + _this.container.children("ul:eq(0)").get(0).className + "' />");
								var tmp = tree_component.drag_drop.drag_node.clone();
								if(_this.settings.languages.length > 0) tmp.find("a").not("." + _this.current_lang).hide();
								tree_component.drag_drop.drag_help.children("ul:eq(0)").append(tmp);
								tree_component.drag_drop.drag_help.find("li:eq(0)").removeClass("last").addClass("last").children("a").html("<ins>&nbsp;</ins>Multiple selection").end().children("ul").remove();

								tree_component.drag_drop.dragged = _this.container.find("li.dragged");
							}
						}
						else {
							if(_this.check("draggable", obj)) {
								tree_component.drag_drop.drag_node	= obj;
								tree_component.drag_drop.drag_help	= $("<div id='jstree-dragged' class='tree " + ( _this.settings.ui.theme_name != "" ? " tree-" + _this.settings.ui.theme_name : "" ) + "' />").append("<ul class='" + _this.container.children("ul:eq(0)").get(0).className + "' />");
								var tmp = obj.clone();
								if(_this.settings.languages.length > 0) tmp.find("a").not("." + _this.current_lang).hide();
								tree_component.drag_drop.drag_help.children("ul:eq(0)").append(tmp);
								tree_component.drag_drop.drag_help.find("li:eq(0)").removeClass("last").addClass("last");
								tree_component.drag_drop.isdown		= true;
								tree_component.drag_drop.foreign	= false;
								tree_component.drag_drop.origin_tree = _this;
								obj.addClass("dragged");

								tree_component.drag_drop.dragged = _this.container.find("li.dragged");
							}
						}
						tree_component.drag_drop.init_x = event.pageX;
						tree_component.drag_drop.init_y = event.pageY;
						obj.blur();
						event.preventDefault(); 
						event.stopPropagation();
						return false;
					});
			},
			focus : function () {
				if(this.locked) return false;
				if(tree_component.focused != this.cntr) {
					tree_component.focused = this.cntr;
					this.callback("onfocus",[this]);
				}
			},

			off_height : function () {
				if(this.offset === false) {
					this.container.css({ position : "relative" });
					this.offset = this.container.offset();
					var tmp = 0;
					tmp = parseInt($.curCSS(this.container.get(0), "paddingTop", true),10);
					if(tmp) this.offset.top += tmp;
					tmp = parseInt($.curCSS(this.container.get(0), "borderTopWidth", true),10);
					if(tmp) this.offset.top += tmp;
					this.container.css({ position : "" });
				}
				if(!this.li_height) {
					var tmp = this.container.find("ul li.closed, ul li.leaf").eq(0);
					this.li_height = tmp.height();
					if(tmp.children("ul:eq(0)").size()) this.li_height -= tmp.children("ul:eq(0)").height();
					if(!this.li_height) this.li_height = 18;
				}
			},
			scroll_check : function (x,y) { 
				var _this = this;
				var cnt = _this.container;
				var off = _this.container.offset();

				var st = cnt.scrollTop();
				var sl = cnt.scrollLeft();
				// DETECT HORIZONTAL SCROLL
				var h_cor = (cnt.get(0).scrollWidth > cnt.width()) ? 40 : 20;

				if(y - off.top < 20)						cnt.scrollTop(Math.max( (st - _this.settings.ui.scroll_spd) ,0));	// NEAR TOP
				if(cnt.height() - (y - off.top) < h_cor)	cnt.scrollTop(st + _this.settings.ui.scroll_spd);					// NEAR BOTTOM
				if(x - off.left < 20)						cnt.scrollLeft(Math.max( (sl - _this.settings.ui.scroll_spd),0));	// NEAR LEFT
				if(cnt.width() - (x - off.left) < 40)		cnt.scrollLeft(sl + _this.settings.ui.scroll_spd);					// NEAR RIGHT

				if(cnt.scrollLeft() != sl || cnt.scrollTop() != st) {
					tree_component.drag_drop.move_type	= false;
					tree_component.drag_drop.ref_node	= false;
					tree_component.drag_drop.marker.hide();
				}
				tree_component.drag_drop.scroll_time = setTimeout( function() { _this.scroll_check(x,y); }, 50);
			},
			scroll_into_view : function (obj) {
				obj = obj ? this.get_node(obj) : this.selected;
				if(!obj) return false;
				var off_t = obj.offset().top;
				var beg_t = this.container.offset().top;
				var end_t = beg_t + this.container.height();
				var h_cor = (this.container.get(0).scrollWidth > this.container.width()) ? 40 : 20;
				if(off_t + 5 < beg_t) this.container.scrollTop(this.container.scrollTop() - (beg_t - off_t + 5) );
				if(off_t + h_cor > end_t) this.container.scrollTop(this.container.scrollTop() + (off_t + h_cor - end_t) );
			},

			get_node : function (obj) {
				return $(obj).closest("li");
			},
			get_type : function (obj) {
				obj = !obj ? this.selected : this.get_node(obj);
				if(!obj) return;
				var tmp = obj.attr(this.settings.rules.type_attr);
				return tmp || "default";
			},
			set_type : function (str, obj) {
				obj = !obj ? this.selected : this.get_node(obj);
				if(!obj || !str) return;
				obj.attr(this.settings.rules.type_attr, str);
			},
			get_text : function (obj, lang) {
				obj = this.get_node(obj);
				if(!obj || obj.size() == 0) return "";
				if(this.settings.languages && this.settings.languages.length) {
					lang = lang ? lang : this.current_lang;
					obj = obj.children("a." + lang);
				}
				else obj = obj.children("a:visible");
				var val = "";
				obj.contents().each(function () {
					if(this.nodeType == 3) { val = this.data; return false; }
				});
				return val;
			},

			check : function (rule, obj) {
				if(this.locked) return false;
				var v = false;
				// if root node
				if(obj === -1) { if(typeof this.settings.rules[rule] != "undefined") v = this.settings.rules[rule]; }
				else {
					obj = !obj ? this.selected : this.get_node(obj);
					if(!obj) return;
					var t = this.get_type(obj);
					if(typeof this.settings.types[t] != "undefined" && typeof this.settings.types[t][rule] != "undefined") v = this.settings.types[t][rule];
					else if(typeof this.settings.types["default"] != "undefined" && typeof this.settings.types["default"][rule] != "undefined") v = this.settings.types["default"][rule];
				}
				if(typeof v == "function") v = v.call(null, obj, this);
				v = this.callback("check", [rule, obj, v, this]);
				return v;
			},
			check_move : function (nod, ref_node, how) {
				if(this.locked) return false;
				if($(ref_node).closest("li.dragged").size()) return false;

				var tree1 = nod.parents(".tree:eq(0)").get(0);
				var tree2 = ref_node.parents(".tree:eq(0)").get(0);
				// if different trees
				if(tree1 && tree1 != tree2) {
					var m = $.tree.reference(tree2.id).settings.rules.multitree;
					if(m == "none" || ($.isArray(m) && $.inArray(tree1.id, m) == -1)) return false;
				}

				var p = (how != "inside") ? this.parent(ref_node) : this.get_node(ref_node);
				nod = this.get_node(nod);
				if(p == false) return false;
				var r = {
					max_depth : this.settings.rules.use_max_depth ? this.check("max_depth", p) : -1,
					max_children : this.settings.rules.use_max_children ? this.check("max_children", p) : -1,
					valid_children : this.check("valid_children", p)
				};
				var nod_type = (typeof nod == "string") ? nod : this.get_type(nod);
				if(typeof r.valid_children != "undefined" && (r.valid_children == "none" || (typeof r.valid_children == "object" && $.inArray(nod_type, $.makeArray(r.valid_children)) == -1))) return false;
				
				if(this.settings.rules.use_max_children) {
					if(typeof r.max_children != "undefined" && r.max_children != -1) {
						if(r.max_children == 0) return false;
						var c_count = 1;
						if(tree_component.drag_drop.moving == true && tree_component.drag_drop.foreign == false) {
							c_count = tree_component.drag_drop.dragged.size();
							c_count = c_count - p.find('> ul > li.dragged').size();
						}
						if(r.max_children < p.find('> ul > li').size() + c_count) return false;
					}
				}

				if(this.settings.rules.use_max_depth) {
					if(typeof r.max_depth != "undefined" && r.max_depth === 0) return this.error("MOVE: MAX-DEPTH REACHED");
					// check for max_depth up the chain
					var mx = (r.max_depth > 0) ? r.max_depth : false;
					var i = 0;
					var t = p;
					while(t !== -1) {
						t = this.parent(t);
						i ++;
						var m = this.check("max_depth",t);
						if(m >= 0) {
							mx = (mx === false) ? (m - i) : Math.min(mx, m - i);
						}
						if(mx !== false && mx <= 0) return this.error("MOVE: MAX-DEPTH REACHED");
					}
					if(mx !== false && mx <= 0) return this.error("MOVE: MAX-DEPTH REACHED");
					if(mx !== false) { 
						var incr = 1;
						if(typeof nod != "string") {
							var t = nod;
							// possible async problem - when nodes are not all loaded down the chain
							while(t.size() > 0) {
								if(mx - incr < 0) return this.error("MOVE: MAX-DEPTH REACHED");
								t = t.children("ul").children("li");
								incr ++;
							}
						}
					}
				}
				if(this.callback("check_move", [nod, ref_node, how, this]) == false) return false;
				return true;
			},

			hover_branch : function (obj) {
				if(this.locked) return this.error("LOCKED");
				var _this = this;
				var obj = _this.get_node(obj);
				if(!obj.size()) return this.error("HOVER: NOT A VALID NODE");
				if(!_this.check("clickable", obj)) return this.error("SELECT: NODE NOT SELECTABLE");
				if(this.hovered) this.hovered.children("A").removeClass("hover");
				this.hovered = obj;
				this.hovered.children("a").addClass("hover");
				this.scroll_into_view(this.hovered);
			},
			select_branch : function (obj, multiple) {
				if(this.locked) return this.error("LOCKED");
				if(!obj && this.hovered !== false) obj = this.hovered;
				var _this = this;
				obj = _this.get_node(obj);
				if(!obj.size()) return this.error("SELECT: NOT A VALID NODE");
				obj.children("a").removeClass("hover");
				// CHECK AGAINST RULES FOR SELECTABLE NODES
				if(!_this.check("clickable", obj)) return this.error("SELECT: NODE NOT SELECTABLE");
				if(_this.callback("beforechange",[obj.get(0),_this]) === false) return this.error("SELECT: STOPPED BY USER");
				// IF multiple AND obj IS ALREADY SELECTED - DESELECT IT
				if(this.settings.rules.multiple != false && multiple && obj.children("a.clicked").size() > 0) {
					return this.deselect_branch(obj);
				}
				if(this.settings.rules.multiple != false && multiple) {
					this.selected_arr.push(obj);
				}
				if(this.settings.rules.multiple != false && !multiple) {
					for(var i in this.selected_arr) {
						if(!this.selected_arr.hasOwnProperty(i)) continue;
						this.selected_arr[i].children("A").removeClass("clicked");
						this.callback("ondeselect", [this.selected_arr[i].get(0), _this]);
					}
					this.selected_arr = [];
					this.selected_arr.push(obj);
					if(this.selected && this.selected.children("A").hasClass("clicked")) {
						this.selected.children("A").removeClass("clicked");
						this.callback("ondeselect", [this.selected.get(0), _this]);
					}
				}
				if(!this.settings.rules.multiple) {
					if(this.selected) {
						this.selected.children("A").removeClass("clicked");
						this.callback("ondeselect", [this.selected.get(0), _this]);
					}
				}
				// SAVE NEWLY SELECTED
				this.selected = obj;
				if(this.hovered !== false) {
					this.hovered.children("A").removeClass("hover");
					this.hovered = obj;
				}

				// FOCUS NEW NODE AND OPEN ALL PARENT NODES IF CLOSED
				this.selected.children("a").addClass("clicked").end().parents("li.closed").each( function () { _this.open_branch(this, true); });

				// SCROLL SELECTED NODE INTO VIEW
				this.scroll_into_view(this.selected);

				this.callback("onselect", [this.selected.get(0), _this]);
				this.callback("onchange", [this.selected.get(0), _this]);
			},
			deselect_branch : function (obj) {
				if(this.locked) return this.error("LOCKED");
				var _this = this;
				var obj = this.get_node(obj);
				if(obj.children("a.clicked").size() == 0) return this.error("DESELECT: NODE NOT SELECTED");

				obj.children("a").removeClass("clicked");
				this.callback("ondeselect", [obj.get(0), _this]);
				if(this.settings.rules.multiple != false && this.selected_arr.length > 1) {
					this.selected_arr = [];
					this.container.find("a.clicked").filter(":first-child").parent().each(function () {
						_this.selected_arr.push($(this));
					});
					if(obj.get(0) == this.selected.get(0)) {
						this.selected = this.selected_arr[0];
					}
				}
				else {
					if(this.settings.rules.multiple != false) this.selected_arr = [];
					this.selected = false;
				}
				this.callback("onchange", [obj.get(0), _this]);
			},
			toggle_branch : function (obj) {
				if(this.locked) return this.error("LOCKED");
				var obj = this.get_node(obj);
				if(obj.hasClass("closed"))	return this.open_branch(obj);
				if(obj.hasClass("open"))	return this.close_branch(obj); 
			},
			open_branch : function (obj, disable_animation, callback) {
				var _this = this;

				if(this.locked) return this.error("LOCKED");
				var obj = this.get_node(obj);
				if(!obj.size()) return this.error("OPEN: NO SUCH NODE");
				if(obj.hasClass("leaf")) return this.error("OPEN: OPENING LEAF NODE");
				if(this.settings.data.async && obj.find("li").size() == 0) {
					
					if(this.callback("beforeopen",[obj.get(0),this]) === false) return this.error("OPEN: STOPPED BY USER");

					obj.children("ul:eq(0)").remove().end().append("<ul><li class='last'><a class='loading' href='#'><ins>&nbsp;</ins>" + (_this.settings.lang.loading || "Loading ...") + "</a></li></ul>");
					obj.removeClass("closed").addClass("open");

					var _datastore = new $.tree.datastores[this.settings.data.type]();
					_datastore.load(this.callback("beforedata",[obj,this]),this,this.settings.data.opts,function(data){
						data = _this.callback("ondata", [data, _this]);
						if(!data || data.length == 0) {
							obj.removeClass("closed").removeClass("open").addClass("leaf").children("ul").remove();
							if(callback) callback.call();
							return;
						}
						_datastore.parse(data,_this,_this.settings.data.opts,function(str){
							str = _this.callback("onparse", [str, _this]);
							// if(obj.children('ul:eq(0)').children('li').size() > 1) obj.children("ul").find('.loaading').parent().replaceWith(str); else 
							obj.children("ul:eq(0)").replaceWith($("<ul>").html(str));
							obj.find("li:last-child").addClass("last").end().find("li:has(ul)").not(".open").addClass("closed");
							obj.find("li").not(".open").not(".closed").addClass("leaf");
							_this.open_branch.apply(_this, [obj]);
							if(callback) callback.call();
						});
					});
					return true;
				}
				else {
					if(!this.settings.data.async) {
						if(this.callback("beforeopen",[obj.get(0),this]) === false) return this.error("OPEN: STOPPED BY USER");
					}
					if(parseInt(this.settings.ui.animation) > 0 && !disable_animation ) {
						obj.children("ul:eq(0)").css("display","none");
						obj.removeClass("closed").addClass("open");
						obj.children("ul:eq(0)").slideDown(parseInt(this.settings.ui.animation), function() {
							$(this).css("display","");
							if(callback) callback.call();
						});
					} else {
						obj.removeClass("closed").addClass("open");
						if(callback) callback.call();
					}
					this.callback("onopen", [obj.get(0), this]);
					return true;
				}
			},
			close_branch : function (obj, disable_animation) {
				if(this.locked) return this.error("LOCKED");
				var _this = this;
				var obj = this.get_node(obj);
				if(!obj.size()) return this.error("CLOSE: NO SUCH NODE");
				if(_this.callback("beforeclose",[obj.get(0),_this]) === false) return this.error("CLOSE: STOPPED BY USER");
				if(parseInt(this.settings.ui.animation) > 0 && !disable_animation && obj.children("ul:eq(0)").size() == 1) {
					obj.children("ul:eq(0)").slideUp(parseInt(this.settings.ui.animation), function() {
						if(obj.hasClass("open")) obj.removeClass("open").addClass("closed");
						$(this).css("display","");
					});
				} 
				else {
					if(obj.hasClass("open")) obj.removeClass("open").addClass("closed");
				}
				if(this.selected && this.settings.ui.selected_parent_close !== false && obj.children("ul:eq(0)").find("a.clicked").size() > 0) {
					obj.find("li:has(a.clicked)").each(function() {
						_this.deselect_branch(this);
					});
					if(this.settings.ui.selected_parent_close == "select_parent" && obj.children("a.clicked").size() == 0) this.select_branch(obj, (this.settings.rules.multiple != false && this.selected_arr.length > 0) );
				}
				this.callback("onclose", [obj.get(0), this]);
			},
			open_all : function (obj, callback) {
				if(this.locked) return this.error("LOCKED");
				var _this = this;
				obj = obj ? this.get_node(obj) : this.container;

				var s = obj.find("li.closed").size();
				if(!callback)	this.cl_count = 0;
				else			this.cl_count --;
				if(s > 0) {
					this.cl_count += s;
					// maybe add .andSelf()
					obj.find("li.closed").each( function () { var __this = this; _this.open_branch.apply(_this, [this, true, function() { _this.open_all.apply(_this, [__this, true]); } ]); });
				}
				else if(this.cl_count == 0) this.callback("onopen_all",[this]);
			},
			close_all : function (obj) {
				if(this.locked) return this.error("LOCKED");
				var _this = this;
				obj = obj ? this.get_node(obj) : this.container;
				// maybe add .andSelf()
				obj.find("li.open").each( function () { _this.close_branch(this, true); });
				this.callback("onclose_all",[this]);
			},

			set_lang : function (i) { 
				if(!$.isArray(this.settings.languages) || this.settings.languages.length == 0) return false;
				if(this.locked) return this.error("LOCKED");
				if(!$.inArray(i,this.settings.languages) && typeof this.settings.languages[i] != "undefined") i = this.settings.languages[i];
				if(typeof i == "undefined") return false;
				if(i == this.current_lang) return true;
				var st = false;
				var id = "#" + this.container.attr("id");
				st = tree_component.get_css(id + " ." + this.current_lang);
				if(st !== false) st.style.display = "none";
				st = tree_component.get_css(id + " ." + i);
				if(st !== false) st.style.display = "";
				this.current_lang = i;
				return true;
			},
			get_lang : function () {
				if(!$.isArray(this.settings.languages) || this.settings.languages.length == 0) return false;
				return this.current_lang;
			},

			create : function (obj, ref_node, position) { 
				if(this.locked) return this.error("LOCKED");
				
				var root = false;
				if(ref_node == -1) { root = true; ref_node = this.container; }
				else ref_node = ref_node ? this.get_node(ref_node) : this.selected;

				if(!root && (!ref_node || !ref_node.size())) return this.error("CREATE: NO NODE SELECTED");

				var pos = position;

				var tmp = ref_node; // for type calculation
				if(position == "before") {
					position = ref_node.parent().children().index(ref_node);
					ref_node = ref_node.parents("li:eq(0)");
				}
				if(position == "after") {
					position = ref_node.parent().children().index(ref_node) + 1;
					ref_node = ref_node.parents("li:eq(0)");
				}
				if(!root && ref_node.size() == 0) { root = true; ref_node = this.container; }

				if(!root) {
					if(!this.check("creatable", ref_node)) return this.error("CREATE: CANNOT CREATE IN NODE");
					if(ref_node.hasClass("closed")) {
						if(this.settings.data.async && ref_node.children("ul").size() == 0) {
							var _this = this;
							return this.open_branch(ref_node, true, function () { _this.create.apply(_this, [obj, ref_node, position]); } );
						}
						else this.open_branch(ref_node, true);
					}
				}

				// creating new object to pass to parseJSON
				var torename = false; 
				if(!obj)	obj = {};
				else		obj = $.extend(true, {}, obj);
				if(!obj.attributes) obj.attributes = {};
				if(!obj.attributes[this.settings.rules.type_attr]) obj.attributes[this.settings.rules.type_attr] = this.get_type(tmp) || "default";
				if(this.settings.languages.length) {
					if(!obj.data) { obj.data = {}; torename = true; }
					for(var i = 0; i < this.settings.languages.length; i++) {
						if(!obj.data[this.settings.languages[i]]) obj.data[this.settings.languages[i]] = ((typeof this.settings.lang.new_node).toLowerCase() != "string" && this.settings.lang.new_node[i]) ? this.settings.lang.new_node[i] : this.settings.lang.new_node;
					}
				}
				else {
					if(!obj.data) { obj.data = this.settings.lang.new_node; torename = true; }
				}

				obj = this.callback("ondata",[obj, this]);
				var obj_s = $.tree.datastores.json().parse(obj,this);
				obj_s = this.callback("onparse", [obj_s, this]);
				var $li = $(obj_s);

				if($li.children("ul").size()) {
					if(!$li.is(".open")) $li.addClass("closed");
				}
				else $li.addClass("leaf");
				$li.find("li:last-child").addClass("last").end().find("li:has(ul)").not(".open").addClass("closed");
				$li.find("li").not(".open").not(".closed").addClass("leaf");

				var r = {
					max_depth : this.settings.rules.use_max_depth ? this.check("max_depth", (root ? -1 : ref_node) ) : -1,
					max_children : this.settings.rules.use_max_children ? this.check("max_children", (root ? -1 : ref_node) ) : -1,
					valid_children : this.check("valid_children", (root ? -1 : ref_node) )
				};
				var nod_type = this.get_type($li);
				if(typeof r.valid_children != "undefined" && (r.valid_children == "none" || ($.isArray(r.valid_children) && $.inArray(nod_type, r.valid_children) == -1))) return this.error("CREATE: NODE NOT A VALID CHILD");

				if(this.settings.rules.use_max_children) {
					if(typeof r.max_children != "undefined" && r.max_children != -1 && r.max_children >= this.children(ref_node).size()) return this.error("CREATE: MAX_CHILDREN REACHED");
				}

				if(this.settings.rules.use_max_depth) {
					if(typeof r.max_depth != "undefined" && r.max_depth === 0) return this.error("CREATE: MAX-DEPTH REACHED");
					// check for max_depth up the chain
					var mx = (r.max_depth > 0) ? r.max_depth : false;
					var i = 0;
					var t = ref_node;

					while(t !== -1 && !root) {
						t = this.parent(t);
						i ++;
						var m = this.check("max_depth",t);
						if(m >= 0) {
							mx = (mx === false) ? (m - i) : Math.min(mx, m - i);
						}
						if(mx !== false && mx <= 0) return this.error("CREATE: MAX-DEPTH REACHED");
					}
					if(mx !== false && mx <= 0) return this.error("CREATE: MAX-DEPTH REACHED");
					if(mx !== false) { 
						var incr = 1;
						var t = $li;
						while(t.size() > 0) {
							if(mx - incr < 0) return this.error("CREATE: MAX-DEPTH REACHED");
							t = t.children("ul").children("li");
							incr ++;
						}
					}
				}

				if((typeof position).toLowerCase() == "undefined" || position == "inside") 
					position = (this.settings.rules.createat == "top") ? 0 : ref_node.children("ul:eq(0)").children("li").size();
				if(ref_node.children("ul").size() == 0 || (root == true && ref_node.children("ul").children("li").size() == 0) ) {
					if(!root)	var a = this.moved($li,ref_node.children("a:eq(0)"),"inside", true);
					else		var a = this.moved($li,this.container.children("ul:eq(0)"),"inside", true);
				}
				else if(pos == "before" && ref_node.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").size())
					var a = this.moved($li,ref_node.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").children("a:eq(0)"),"before", true);
				else if(pos == "after" &&  ref_node.children("ul:eq(0)").children("li:nth-child(" + (position) + ")").size())
					var a = this.moved($li,ref_node.children("ul:eq(0)").children("li:nth-child(" + (position) + ")").children("a:eq(0)"),"after", true);
				else if(ref_node.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").size())
					var a = this.moved($li,ref_node.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").children("a:eq(0)"),"before", true);
				else
					var a = this.moved($li,ref_node.children("ul:eq(0)").children("li:last").children("a:eq(0)"),"after",true);

				if(a === false) return this.error("CREATE: ABORTED");

				if(torename) {
					this.select_branch($li.children("a:eq(0)"));
					this.rename();
				}
				return $li;
			},
			rename : function (obj, new_name) {
				if(this.locked) return this.error("LOCKED");
				obj = obj ? this.get_node(obj) : this.selected;
				var _this = this;
				if(!obj || !obj.size()) return this.error("RENAME: NO NODE SELECTED");
				if(!this.check("renameable", obj)) return this.error("RENAME: NODE NOT RENAMABLE");
				if(!this.callback("beforerename",[obj.get(0), _this.current_lang, _this])) return this.error("RENAME: STOPPED BY USER");

				obj.parents("li.closed").each(function () { _this.open_branch(this) });
				if(this.current_lang)	obj = obj.find("a." + this.current_lang);
				else					obj = obj.find("a:first");

				// Rollback
				var rb = {}; 
				rb[this.container.attr("id")] = this.get_rollback();

				var icn = obj.children("ins").clone();
				if((typeof new_name).toLowerCase() == "string") {
					obj.text(new_name).prepend(icn);
					_this.callback("onrename", [_this.get_node(obj).get(0), _this, rb]);
				}
				else {
					var last_value = "";
					obj.contents().each(function () {
						if(this.nodeType == 3) { last_value = this.data; return false; }
					});
					_this.inp = $("<input type='text' autocomplete='off' />");
					_this.inp
						.val(last_value.replace(/&amp;/g,"&").replace(/&gt;/g,">").replace(/&lt;/g,"<"))
						.bind("mousedown",		function (event) { event.stopPropagation(); })
						.bind("mouseup",		function (event) { event.stopPropagation(); })
						.bind("click",			function (event) { event.stopPropagation(); })
						.bind("keyup",			function (event) { 
								var key = event.keyCode || event.which;
								if(key == 27) { this.value = last_value; this.blur(); return }
								if(key == 13) { this.blur(); return; }
							});
					_this.inp.blur(function(event) {
							if(this.value == "") this.value = last_value; 
							obj.text(this.value).prepend(icn);
							obj.get(0).style.display = ""; 
							obj.prevAll("span").remove(); 
							_this.inp = false;
							_this.callback("onrename", [_this.get_node(obj).get(0), _this, rb]);
						});

					var spn = $("<span />").addClass(obj.attr("class")).append(icn).append(_this.inp);
					obj.get(0).style.display = "none";
					obj.parent().prepend(spn);
					_this.inp.get(0).focus();
					_this.inp.get(0).select();
				}
			},
			remove : function(obj) {
				if(this.locked) return this.error("LOCKED");
				var _this = this;

				// Rollback
				var rb = {}; 
				rb[this.container.attr("id")] = this.get_rollback();

				if(obj && (!this.selected || this.get_node(obj).get(0) != this.selected.get(0) )) {
					obj = this.get_node(obj);
					if(obj.size()) {
						if(!this.check("deletable", obj)) return this.error("DELETE: NODE NOT DELETABLE");
						if(!this.callback("beforedelete",[obj.get(0), _this])) return this.error("DELETE: STOPPED BY USER");
						$parent = obj.parent();
						if(obj.find("a.clicked").size()) {
							var reset_selected = false;
							_this.selected_arr = [];
							this.container.find("a.clicked").filter(":first-child").parent().each(function () {
								if(!reset_selected && this == _this.selected.get(0)) reset_selected = true;
								if($(this).parents().index(obj) != -1) return true;
								_this.selected_arr.push($(this));
							});
							if(reset_selected) this.selected = this.selected_arr[0] || false;
						}
						obj = obj.remove();
						$parent.children("li:last").addClass("last");
						if($parent.children("li").size() == 0) {
							$li = $parent.parents("li:eq(0)");
							$li.removeClass("open").removeClass("closed").addClass("leaf").children("ul").remove();
						}
						this.callback("ondelete", [obj.get(0), this, rb]);
					}
				}
				else if(this.selected) {
					if(!this.check("deletable", this.selected)) return this.error("DELETE: NODE NOT DELETABLE");
					if(!this.callback("beforedelete",[this.selected.get(0), _this])) return this.error("DELETE: STOPPED BY USER");
					$parent = this.selected.parent();
					var obj = this.selected;
					if(this.settings.rules.multiple == false || this.selected_arr.length == 1) {
						var stop = true;
						var tmp = this.settings.ui.selected_delete == "select_previous" ? this.prev(this.selected) : false;
					}
					obj = obj.remove();
					$parent.children("li:last").addClass("last");
					if($parent.children("li").size() == 0) {
						$li = $parent.parents("li:eq(0)");
						$li.removeClass("open").removeClass("closed").addClass("leaf").children("ul").remove();
					}
					if(!stop && this.settings.rules.multiple != false) {
						var _this = this;
						this.selected_arr = [];
						this.container.find("a.clicked").filter(":first-child").parent().each(function () {
							_this.selected_arr.push($(this));
						});
						if(this.selected_arr.length > 0) {
							this.selected = this.selected_arr[0];
							this.remove();
						}
					}
					if(stop && tmp) this.select_branch(tmp); 
					this.callback("ondelete", [obj.get(0), this, rb]);
				}
				else return this.error("DELETE: NO NODE SELECTED");
			},

			next : function (obj, strict) {
				obj = this.get_node(obj);
				if(!obj.size()) return false;
				if(strict) return (obj.nextAll("li").size() > 0) ? obj.nextAll("li:eq(0)") : false;

				if(obj.hasClass("open")) return obj.find("li:eq(0)");
				else if(obj.nextAll("li").size() > 0) return obj.nextAll("li:eq(0)");
				else return obj.parents("li").next("li").eq(0);
			},
			prev : function(obj, strict) {
				obj = this.get_node(obj);
				if(!obj.size()) return false;
				if(strict) return (obj.prevAll("li").size() > 0) ? obj.prevAll("li:eq(0)") : false;

				if(obj.prev("li").size()) {
					var obj = obj.prev("li").eq(0);
					while(obj.hasClass("open")) obj = obj.children("ul:eq(0)").children("li:last");
					return obj;
				}
				else return obj.parents("li:eq(0)").size() ? obj.parents("li:eq(0)") : false;
			},
			parent : function(obj) {
				obj = this.get_node(obj);
				if(!obj.size()) return false;
				return obj.parents("li:eq(0)").size() ? obj.parents("li:eq(0)") : -1;
			},
			children : function(obj) {
				if(obj === -1) return this.container.children("ul:eq(0)").children("li");

				obj = this.get_node(obj);
				if(!obj.size()) return false;
				return obj.children("ul:eq(0)").children("li");
			},

			toggle_dots : function () {
				if(this.settings.ui.dots) {
					this.settings.ui.dots = false;
					this.container.children("ul:eq(0)").addClass("no_dots");
				}
				else {
					this.settings.ui.dots = true;
					this.container.children("ul:eq(0)").removeClass("no_dots");
				}
			},

			callback : function (cb, args) {
				var p = false;
				var r = null;
				for(var i in this.settings.plugins) {
					if(typeof $.tree.plugins[i] != "object") continue;
					p = $.tree.plugins[i];
					if(p.callbacks && typeof p.callbacks[cb] == "function") r = p.callbacks[cb].apply(this, args);
					if(typeof r !== "undefined" && r !== null) {
						if(cb == "ondata" || cb == "onparse") args[0] = r; // keep the chain if data or parse
						else return r;
					}
				}
				p = this.settings.callback[cb];
				if(typeof p == "function") return p.apply(null, args);
			},
			get_rollback : function () {
				var rb = {};
				rb.html = this.container.html();
				rb.selected = this.selected ? this.selected.attr("id") : false;
				return rb;
			},
			moved : function (what, where, how, is_new, is_copy, rb) {
				var what	= $(what);
				var $parent	= $(what).parents("ul:eq(0)");
				var $where	= $(where);
				if($where.is("ins")) $where = $where.parent();

				// Rollback
				if(!rb) {
					var rb = {}; 
					rb[this.container.attr("id")] = this.get_rollback();
					if(!is_new) {
						var tmp = what.size() > 1 ? what.eq(0).parents(".tree:eq(0)") : what.parents(".tree:eq(0)");
						if(tmp.get(0) != this.container.get(0)) {
							tmp = tree_component.inst[tmp.attr("id")];
							rb[tmp.container.attr("id")] = tmp.get_rollback();
						}
						delete tmp;
					}
				}

				if(how == "inside" && this.settings.data.async) {
					var _this = this;
					if(this.get_node($where).hasClass("closed")) {
						return this.open_branch(this.get_node($where), true, function () { _this.moved.apply(_this, [what, where, how, is_new, is_copy, rb]); });
					}
					if(this.get_node($where).find("> ul > li > a.loading").size() == 1) {
						setTimeout(function () { _this.moved.apply(_this, [what, where, how, is_new, is_copy]); }, 200);
						return;
					}
				}


				// IF MULTIPLE
				if(what.size() > 1) {
					var _this = this;
					var tmp = this.moved(what.eq(0), where, how, false, is_copy, rb);
					what.each(function (i) {
						if(i == 0) return;
						if(tmp) { // if tmp is false - the previous move was a no-go
							tmp = _this.moved(this, tmp.children("a:eq(0)"), "after", false, is_copy, rb);
						}
					});
					return what;
				}

				if(is_copy) {
					_what = what.clone();
					_what.each(function (i) {
						this.id = this.id + "_copy";
						$(this).find("li").each(function () {
							this.id = this.id + "_copy";
						});
						$(this).removeClass("dragged").find("a.clicked").removeClass("clicked").end().find("li.dragged").removeClass("dragged");
					});
				}
				else _what = what;
				if(is_new) {
					if(!this.callback("beforecreate", [this.get_node(what).get(0), this.get_node(where).get(0),how,this])) return false;
				}
				else {
					if(!this.callback("beforemove", [this.get_node(what).get(0), this.get_node(where).get(0),how,this])) return false;
				}

				if(!is_new) {
					var tmp = what.parents(".tree:eq(0)");
					// if different trees
					if(tmp.get(0) != this.container.get(0)) {
						tmp = tree_component.inst[tmp.attr("id")];

						// if there are languages - otherwise - no cleanup needed
						if(tmp.settings.languages.length) {
							var res = [];
							// if new tree has no languages - use current visible
							if(this.settings.languages.length == 0) res.push("." + tmp.current_lang);
							else {
								for(var i in this.settings.languages) {
									if(!this.settings.languages.hasOwnProperty(i)) continue;
									for(var j in tmp.settings.languages) {
										if(!tmp.settings.languages.hasOwnProperty(j)) continue;
										if(this.settings.languages[i] == tmp.settings.languages[j]) res.push("." + this.settings.languages[i]);
									}
								}
							}
							if(res.length == 0) return this.error("MOVE: NO COMMON LANGUAGES");
							_what.find("a").not(res.join(",")).remove();
						}
						_what.find("a.clicked").removeClass("clicked");
					}
				}
				what = _what;

				// ADD NODE TO NEW PLACE
				switch(how) {
					case "before":
						$where.parents("ul:eq(0)").children("li.last").removeClass("last");
						$where.parent().before(what.removeClass("last"));
						$where.parents("ul:eq(0)").children("li:last").addClass("last");
						break;
					case "after":
						$where.parents("ul:eq(0)").children("li.last").removeClass("last");
						$where.parent().after(what.removeClass("last"));
						$where.parents("ul:eq(0)").children("li:last").addClass("last");
						break;
					case "inside":
						if($where.parent().children("ul:first").size()) {
							if(this.settings.rules.createat == "top") {
								$where.parent().children("ul:first").prepend(what.removeClass("last")).children("li:last").addClass("last");

								// restored this section
								var tmp_node = $where.parent().children("ul:first").children("li:first");
								if(tmp_node.size()) {
									how = "before";
									where = tmp_node;
								}
							}
							else {
								// restored this section
								var tmp_node = $where.parent().children("ul:first").children(".last");
								if(tmp_node.size()) {
									how = "after";
									where = tmp_node;
								}

								$where.parent().children("ul:first").children(".last").removeClass("last").end().append(what.removeClass("last")).children("li:last").addClass("last");
							}
						}
						else {
							what.addClass("last");
							$where.parent().removeClass("leaf").append("<ul/>");
							if(!$where.parent().hasClass("open")) $where.parent().addClass("closed");
							$where.parent().children("ul:first").prepend(what);
						}
						if($where.parent().hasClass("closed")) { this.open_branch($where); }
						break;
					default:
						break;
				}
				// CLEANUP OLD PARENT
				if($parent.find("li").size() == 0) {
					var $li = $parent.parent();
					$li.removeClass("open").removeClass("closed").addClass("leaf");
					if(!$li.is(".tree")) $li.children("ul").remove();
					$li.parents("ul:eq(0)").children("li.last").removeClass("last").end().children("li:last").addClass("last");
				}
				else {
					$parent.children("li.last").removeClass("last");
					$parent.children("li:last").addClass("last");
				}

				// NO LONGER CORRECT WITH position PARAM - if(is_new && how != "inside") where = this.get_node(where).parents("li:eq(0)");
				if(is_copy)		this.callback("oncopy", [this.get_node(what).get(0), this.get_node(where).get(0), how, this, rb]);
				else if(is_new)	this.callback("oncreate", [this.get_node(what).get(0), ($where.is("ul") ? -1 : this.get_node(where).get(0) ), how, this, rb]);
				else			this.callback("onmove", [this.get_node(what).get(0), this.get_node(where).get(0), how, this, rb]);
				return what;
			},
			error : function (code) {
				this.callback("error",[code,this]);
				return false;
			},
			lock : function (state) {
				this.locked = state;
				if(this.locked)	this.container.children("ul:eq(0)").addClass("locked");
				else			this.container.children("ul:eq(0)").removeClass("locked");
			},
			cut : function (obj) {
				if(this.locked) return this.error("LOCKED");
				obj = obj ? this.get_node(obj) : this.container.find("a.clicked").filter(":first-child").parent();
				if(!obj || !obj.size()) return this.error("CUT: NO NODE SELECTED");
				tree_component.cut_copy.copy_nodes = false;
				tree_component.cut_copy.cut_nodes = obj;
			},
			copy : function (obj) {
				if(this.locked) return this.error("LOCKED");
				obj = obj ? this.get_node(obj) : this.container.find("a.clicked").filter(":first-child").parent();
				if(!obj || !obj.size()) return this.error("COPY: NO NODE SELECTED");
				tree_component.cut_copy.copy_nodes = obj;
				tree_component.cut_copy.cut_nodes = false;
			},
			paste : function (obj, position) {
				if(this.locked) return this.error("LOCKED");

				var root = false;
				if(obj == -1) { root = true; obj = this.container; }
				else obj = obj ? this.get_node(obj) : this.selected;

				if(!root && (!obj || !obj.size())) return this.error("PASTE: NO NODE SELECTED");
				if(!tree_component.cut_copy.copy_nodes && !tree_component.cut_copy.cut_nodes) return this.error("PASTE: NOTHING TO DO");

				var _this = this;

				var pos = position;

				if(position == "before") {
					position = obj.parent().children().index(obj);
					obj = obj.parents("li:eq(0)");
				}
				else if(position == "after") {
					position = obj.parent().children().index(obj) + 1;
					obj = obj.parents("li:eq(0)");
				}
				else if((typeof position).toLowerCase() == "undefined" || position == "inside") {
					position = (this.settings.rules.createat == "top") ? 0 : obj.children("ul:eq(0)").children("li").size();
				}
				if(!root && obj.size() == 0) { root = true; obj = this.container; }

				if(tree_component.cut_copy.copy_nodes && tree_component.cut_copy.copy_nodes.size()) {
					var ok = true;
					if(!root && !this.check_move(tree_component.cut_copy.copy_nodes, obj.children("a:eq(0)"), "inside")) return false;

					if(obj.children("ul").size() == 0 || (root == true && obj.children("ul").children("li").size() == 0) ) {
						if(!root)	var a = this.moved(tree_component.cut_copy.copy_nodes,obj.children("a:eq(0)"),"inside", false, true);
						else		var a = this.moved(tree_component.cut_copy.copy_nodes,this.container.children("ul:eq(0)"),"inside", false, true);
					}
					else if(pos == "before" && obj.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").size())
						var a = this.moved(tree_component.cut_copy.copy_nodes,obj.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").children("a:eq(0)"),"before", false, true);
					else if(pos == "after" && obj.children("ul:eq(0)").children("li:nth-child(" + (position) + ")").size())
						var a = this.moved(tree_component.cut_copy.copy_nodes,obj.children("ul:eq(0)").children("li:nth-child(" + (position) + ")").children("a:eq(0)"),"after", false, true);
					else if(obj.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").size())
						var a = this.moved(tree_component.cut_copy.copy_nodes,obj.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").children("a:eq(0)"),"before", false, true);
					else
						var a = this.moved(tree_component.cut_copy.copy_nodes,obj.children("ul:eq(0)").children("li:last").children("a:eq(0)"),"after", false, true);
					tree_component.cut_copy.copy_nodes = false;
				}
				if(tree_component.cut_copy.cut_nodes && tree_component.cut_copy.cut_nodes.size()) {
					var ok = true;
					obj.parents().andSelf().each(function () {
						if(tree_component.cut_copy.cut_nodes.index(this) != -1) {
							ok = false;
							return false;
						}
					});
					if(!ok) return this.error("Invalid paste");
					if(!root && !this.check_move(tree_component.cut_copy.cut_nodes, obj.children("a:eq(0)"), "inside")) return false;

					if(obj.children("ul").size() == 0 || (root == true && obj.children("ul").children("li").size() == 0) ) {
						if(!root)	var a = this.moved(tree_component.cut_copy.cut_nodes,obj.children("a:eq(0)"),"inside");
						else		var a = this.moved(tree_component.cut_copy.cut_nodes,this.container.children("ul:eq(0)"),"inside");
					}
					else if(pos == "before" && obj.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").size())
						var a = this.moved(tree_component.cut_copy.cut_nodes,obj.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").children("a:eq(0)"),"before");
					else if(pos == "after" && obj.children("ul:eq(0)").children("li:nth-child(" + (position) + ")").size())
						var a = this.moved(tree_component.cut_copy.cut_nodes,obj.children("ul:eq(0)").children("li:nth-child(" + (position) + ")").children("a:eq(0)"),"after");
					else if(obj.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").size())
						var a = this.moved(tree_component.cut_copy.cut_nodes,obj.children("ul:eq(0)").children("li:nth-child(" + (position + 1) + ")").children("a:eq(0)"),"before");
					else
						var a = this.moved(tree_component.cut_copy.cut_nodes,obj.children("ul:eq(0)").children("li:last").children("a:eq(0)"),"after");
					tree_component.cut_copy.cut_nodes = false;
				}
			},
			search : function(str, func) {
				var _this = this;
				if(!str || (this.srch && str != this.srch) ) {
					this.srch = "";
					this.srch_opn = false;
					this.container.find("a.search").removeClass("search");
				}
				this.srch = str;
				if(!str) return;

				if(!func) func = "contains";
				if(this.settings.data.async) {
					if(!this.srch_opn) {
						var dd = $.extend( { "search" : str } , this.callback("beforedata", [false, this] ) );
						$.ajax({
							type		: this.settings.data.opts.method,
							url			: this.settings.data.opts.url, 
							data		: dd, 
							dataType	: "text",
							success		: function (data) {
								_this.srch_opn = $.unique(data.split(","));
								_this.search.apply(_this,[str, func]);
							} 
						});
					}
					else if(this.srch_opn.length) {
						if(this.srch_opn && this.srch_opn.length) {
							var opn = false;
							for(var j = 0; j < this.srch_opn.length; j++) {
								if(this.get_node("#" + this.srch_opn[j]).size() > 0) {
									opn = true;
									var tmp = "#" + this.srch_opn[j];
									delete this.srch_opn[j];
									this.open_branch(tmp, true, function () { _this.search.apply(_this,[str, func]); } );
								}
							}
							if(!opn) {
								this.srch_opn = [];
								 _this.search.apply(_this,[str, func]);
							}
						}
					}
					else {
						this.srch_opn = false;
						var selector = "a";
						// IF LANGUAGE VERSIONS
						if(this.settings.languages.length) selector += "." + this.current_lang;
						this.callback("onsearch", [this.container.find(selector + ":" + func + "('" + str + "')"), this]);
					}
				}
				else {
					var selector = "a";
					// IF LANGUAGE VERSIONS
					if(this.settings.languages.length) selector += "." + this.current_lang;
					var nn = this.container.find(selector + ":" + func + "('" + str + "')");
					nn.parents("li.closed").each( function () { _this.open_branch(this, true); });
					this.callback("onsearch", [nn, this]);
				}
			},
			add_sheet : tree_component.add_sheet,

			destroy : function() {
				this.callback("ondestroy", [this]);

				this.container.unbind(".jstree");
				$("#" + this.container.attr("id")).die("click.jstree").die("dblclick.jstree").die("mouseover.jstree").die("mouseout.jstree").die("mousedown.jstree");
				this.container.removeClass("tree ui-widget ui-widget-content tree-default tree-" + this.settings.ui.theme_name).children("ul").removeClass("no_dots ltr locked").find("li").removeClass("leaf").removeClass("open").removeClass("closed").removeClass("last").children("a").removeClass("clicked hover search");

				if(this.cntr == tree_component.focused) {
					for(var i in tree_component.inst) {
						if(i != this.cntr && i != this.container.attr("id")) {
							tree_component.inst[i].focus();
							break;
						}
					}
				}

				tree_component.inst[this.cntr] = false;
				tree_component.inst[this.container.attr("id")] = false;
				delete tree_component.inst[this.cntr];
				delete tree_component.inst[this.container.attr("id")];
				tree_component.cntr --;
			}
		}
	};

	// instance manager
	tree_component.cntr = 0;
	tree_component.inst = {};

	// themes
	tree_component.themes = [];

	// drag'n'drop stuff
	tree_component.drag_drop = {
		isdown		: false,	// Is there a drag
		drag_node	: false,	// The actual node
		drag_help	: false,	// The helper
		dragged		: false,

		init_x		: false,
		init_y		: false,
		moving		: false,

		origin_tree	: false,
		marker		: false,

		move_type	: false,	// before, after or inside
		ref_node	: false,	// reference node
		appended	: false,	// is helper appended

		foreign		: false,	// Is the dragged node a foreign one
		droppable	: [],		// Array of classes that can be dropped onto the tree

		open_time	: false,	// Timeout for opening nodes
		scroll_time	: false		// Timeout for scrolling
	};
	tree_component.mouseup = function(event) {
		var tmp = tree_component.drag_drop;
		if(tmp.open_time)	clearTimeout(tmp.open_time);
		if(tmp.scroll_time)	clearTimeout(tmp.scroll_time);

		if(tmp.moving && $.tree.drag_end !== false) $.tree.drag_end.call(null, event, tmp);

		if(tmp.foreign === false && tmp.drag_node && tmp.drag_node.size()) {
			tmp.drag_help.remove();
			if(tmp.move_type) {
				var tree1 = tree_component.inst[tmp.ref_node.parents(".tree:eq(0)").attr("id")];
				if(tree1) tree1.moved(tmp.dragged, tmp.ref_node, tmp.move_type, false, (tmp.origin_tree.settings.rules.drag_copy == "on" || (tmp.origin_tree.settings.rules.drag_copy == "ctrl" && event.ctrlKey) ) );
			}
			tmp.move_type	= false;
			tmp.ref_node	= false;
		}
		if(tmp.foreign !== false) {
			if(tmp.drag_help) tmp.drag_help.remove();
			if(tmp.move_type) {
				var tree1 = tree_component.inst[tmp.ref_node.parents(".tree:eq(0)").attr("id")];
				if(tree1) tree1.callback("ondrop",[tmp.f_data, tree1.get_node(tmp.ref_node).get(0), tmp.move_type, tree1]);
			}
			tmp.foreign		= false;
			tmp.move_type	= false;
			tmp.ref_node	= false;
		}
		// RESET EVERYTHING
		if(tree_component.drag_drop.marker) tree_component.drag_drop.marker.hide();
		if(tmp.dragged && tmp.dragged.size()) tmp.dragged.removeClass("dragged");
		tmp.dragged		= false;
		tmp.drag_help	= false;
		tmp.drag_node	= false;
		tmp.f_type		= false;
		tmp.f_data		= false;
		tmp.init_x		= false;
		tmp.init_y		= false;
		tmp.moving		= false;
		tmp.appended	= false;
		tmp.origin_tree	= false;
		if(tmp.isdown) {
			tmp.isdown = false;
			event.preventDefault(); 
			event.stopPropagation();
			return false;
		}
	};
	tree_component.mousemove = function(event) {
		var tmp = tree_component.drag_drop;
		var is_start = false;

		if(tmp.isdown) {
			if(!tmp.moving && Math.abs(tmp.init_x - event.pageX) < 5 && Math.abs(tmp.init_y - event.pageY) < 5) {
				event.preventDefault();
				event.stopPropagation();
				return false;
			}
			else {
				if(!tmp.moving) {
					tree_component.drag_drop.moving = true;
					is_start = true;
				}
			}

			if(tmp.open_time) clearTimeout(tmp.open_time);

			if(tmp.drag_help !== false) {
				if(!tmp.appended) {
					if(tmp.foreign !== false) tmp.origin_tree = $.tree.focused();
					$("body").append(tmp.drag_help);
					tmp.w = tmp.drag_help.width();
					tmp.appended = true;
				}
				tmp.drag_help.css({ "left" : (event.pageX + 5 ), "top" : (event.pageY + 15) });
			}

			if(is_start && $.tree.drag_start !== false) $.tree.drag_start.call(null, event, tmp);
			if($.tree.drag !== false) $.tree.drag.call(null, event, tmp);

			if(event.target.tagName == "DIV" && event.target.id == "jstree-marker") return false;

			var et = $(event.target);
			if(et.is("ins")) et = et.parent();
			var cnt = et.is(".tree") ? et : et.parents(".tree:eq(0)");

			// if not moving over a tree
			if(cnt.size() == 0 || !tree_component.inst[cnt.attr("id")]) {
				if(tmp.scroll_time) clearTimeout(tmp.scroll_time);
				if(tmp.drag_help !== false) tmp.drag_help.find("li:eq(0) ins").addClass("forbidden");
				tmp.move_type	= false;
				tmp.ref_node	= false;
				tree_component.drag_drop.marker.hide();
				return false;
			}

			var tree2 = tree_component.inst[cnt.attr("id")];
			tree2.off_height();

			if(tmp.scroll_time) clearTimeout(tmp.scroll_time);
			tmp.scroll_time = setTimeout( function() { tree2.scroll_check(event.pageX,event.pageY); }, 50);

			var mov = false;
			var st = cnt.scrollTop();

			if(event.target.tagName == "A" || event.target.tagName == "INS") {
				// just in case if hover is over the draggable
				if(et.is("#jstree-dragged")) return false;
				if(tree2.get_node(event.target).hasClass("closed")) {
					tmp.open_time = setTimeout( function () { tree2.open_branch(et); }, 500);
				}

				var et_off = et.offset();
				var goTo = { 
					x : (et_off.left - 1),
					y : (event.pageY - et_off.top)
				};

				var arr = [];
				if(goTo.y < tree2.li_height/3 + 1 )			arr = ["before","inside","after"];
				else if(goTo.y > tree2.li_height*2/3 - 1 )	arr = ["after","inside","before"];
				else {
					if(goTo.y < tree2.li_height/2)			arr = ["inside","before","after"];
					else									arr = ["inside","after","before"];
				}
				var ok = false;
				var nn = (tmp.foreign == false) ? tmp.origin_tree.container.find("li.dragged") : tmp.f_type;
				$.each(arr, function(i, val) {
					if(tree2.check_move(nn, et, val)) {
						mov = val;
						ok = true;
						return false;
					}
				});
				if(ok) {
					switch(mov) {
						case "before":
							goTo.y = et_off.top - 2;
							tree_component.drag_drop.marker.attr("class","marker");
							break;
						case "after":
							goTo.y = et_off.top - 2 + tree2.li_height;
							tree_component.drag_drop.marker.attr("class","marker");
							break;
						case "inside":
							goTo.x -= 2;
							goTo.y = et_off.top - 2 + tree2.li_height/2;
							tree_component.drag_drop.marker.attr("class","marker_plus"); 
							break;
					}
					tmp.move_type	= mov;
					tmp.ref_node	= $(event.target);
					if(tmp.drag_help !== false) tmp.drag_help.find(".forbidden").removeClass("forbidden");
					tree_component.drag_drop.marker.css({ "left" : goTo.x , "top" : goTo.y }).show();
				}
			}

			if( (et.is(".tree") || et.is("ul") ) && et.find("li:eq(0)").size() == 0) {
				var et_off = et.offset();
				tmp.move_type	= "inside";
				tmp.ref_node	= cnt.children("ul:eq(0)");
				if(tmp.drag_help !== false) tmp.drag_help.find(".forbidden").removeClass("forbidden");
				tree_component.drag_drop.marker.attr("class","marker_plus");
				tree_component.drag_drop.marker.css({ "left" : (et_off.left + 10) , "top" : et_off.top + 15 }).show();
			}
			else if( (event.target.tagName != "A" && event.target.tagName != "INS") || !ok) {
				if(tmp.drag_help !== false) tmp.drag_help.find("li:eq(0) ins").addClass("forbidden");
				tmp.move_type	= false;
				tmp.ref_node	= false;
				tree_component.drag_drop.marker.hide();
			}
			event.preventDefault();
			event.stopPropagation();
			return false;
		}
		return true;
	};
	$(function () { 
		$(document).bind("mousemove.jstree",	tree_component.mousemove); 
		$(document).bind("mouseup.jstree",		tree_component.mouseup); 
	});

	// cut, copy, paste stuff
	tree_component.cut_copy = { 
		copy_nodes : false,
		cut_nodes : false
	};

	// css stuff
	tree_component.css = false;
	tree_component.get_css = function(rule_name, delete_flag) {
		rule_name = rule_name.toLowerCase();
		var css_rules = tree_component.css.cssRules || tree_component.css.rules;
		var j = 0;
		do {
			if(css_rules.length && j > css_rules.length + 5) return false;
			if(css_rules[j].selectorText && css_rules[j].selectorText.toLowerCase() == rule_name) {
				if(delete_flag == true) {
					if(tree_component.css.removeRule) document.styleSheets[i].removeRule(j);
					if(tree_component.css.deleteRule) document.styleSheets[i].deleteRule(j);
					return true;
				}
				else return css_rules[j];
			}
		}
		while (css_rules[++j]);
		return false;
	};
	tree_component.add_css = function(rule_name) {
		if(tree_component.get_css(rule_name)) return false;
		(tree_component.css.insertRule) ? tree_component.css.insertRule(rule_name + ' { }', 0) : tree_component.css.addRule(rule_name, null, 0);
		return tree_component.get_css(rule_name);
	};
	tree_component.remove_css = function(rule_name) { 
		return tree_component.get_css(rule_name, true); 
	};
	tree_component.add_sheet = function(opts) {
		if(opts.str) {
			var tmp = document.createElement("style");
			tmp.type = "text/css";
			if(tmp.styleSheet) tmp.styleSheet.cssText = opts.str;
			else tmp.appendChild(document.createTextNode(opts.str));
			document.getElementsByTagName("head")[0].appendChild(tmp);
			return tmp.sheet;
		}
		if(opts.url) {
			if(document.createStyleSheet) {
				try { document.createStyleSheet(opts.url); } catch (e) { };
			}
			else {
				var newSS	= document.createElement('link');
				newSS.rel	= 'stylesheet';
				newSS.type	= 'text/css';
				newSS.media	= "all";
				newSS.href	= opts.url;
				// var styles	= "@import url(' " + url + " ');";
				// newSS.href	='data:text/css,'+escape(styles);
				document.getElementsByTagName("head")[0].appendChild(newSS);
				return newSS.styleSheet;
			}
		}
	};
	$(function () {
		var u = navigator.userAgent.toLowerCase();
		var v = (u.match( /.+(?:rv|it|ra|ie)[\/: ]([\d.]+)/ ) || [0,'0'])[1];
		var css = '/* TREE LAYOUT */ .tree ul { margin:0 0 0 5px; padding:0 0 0 0; list-style-type:none; } .tree li { display:block; min-height:18px; line-height:18px; padding:0 0 0 15px; margin:0 0 0 0; /* Background fix */ clear:both; } .tree li ul { display:none; } .tree li a, .tree li span { display:inline-block;line-height:16px;height:16px;color:black;white-space:nowrap;text-decoration:none;padding:1px 4px 1px 4px;margin:0; } .tree li a:focus { outline: none; } .tree li a input, .tree li span input { margin:0;padding:0 0;display:inline-block;height:12px !important;border:1px solid white;background:white;font-size:10px;font-family:Verdana; } .tree li a input:not([class="xxx"]), .tree li span input:not([class="xxx"]) { padding:1px 0; } /* FOR DOTS */ .tree .ltr li.last { float:left; } .tree > ul li.last { overflow:visible; } /* OPEN OR CLOSE */ .tree li.open ul { display:block; } .tree li.closed ul { display:none !important; } /* FOR DRAGGING */ #jstree-dragged { position:absolute; top:-10px; left:-10px; margin:0; padding:0; } #jstree-dragged ul ul ul { display:none; } #jstree-marker { padding:0; margin:0; line-height:5px; font-size:1px; overflow:hidden; height:5px; position:absolute; left:-45px; top:-30px; z-index:1000; background-color:transparent; background-repeat:no-repeat; display:none; } #jstree-marker.marker { width:45px; background-position:-32px top; } #jstree-marker.marker_plus { width:5px; background-position:right top; } /* BACKGROUND DOTS */ .tree li li { overflow:hidden; } .tree > .ltr > li { display:table; } /* ICONS */ .tree ul ins { display:inline-block; text-decoration:none; width:16px; height:16px; } .tree .ltr ins { margin:0 4px 0 0px; } ';
		if(/msie/.test(u) && !/opera/.test(u)) { 
			if(parseInt(v) == 6) css += '.tree li { height:18px; zoom:1; } .tree li li { overflow:visible; } .tree .ltr li.last { margin-top: expression( (this.previousSibling && /open/.test(this.previousSibling.className) ) ? "-2px" : "0"); } .marker { width:45px; background-position:-32px top; } .marker_plus { width:5px; background-position:right top; }';
			if(parseInt(v) == 7) css += '.tree li li { overflow:visible; } .tree .ltr li.last { margin-top: expression( (this.previousSibling && /open/.test(this.previousSibling.className) ) ? "-2px" : "0"); }';
		}
		if(/opera/.test(u)) css += '.tree > ul > li.last:after { content:"."; display: block; height:1px; clear:both; visibility:hidden; }';
		if(/mozilla/.test(u) && !/(compatible|webkit)/.test(u) && v.indexOf("1.8") == 0) css += '.tree .ltr li a { display:inline; float:left; } .tree li ul { clear:both; }';
		tree_component.css = tree_component.add_sheet({ str : css });
	});
})(jQuery);

// Datastores
// HTML and JSON are included here by default
(function ($) {
	$.extend($.tree.datastores, {
		"html" : function () {
			return {
				get		: function(obj, tree, opts) {
					return obj && $(obj).size() ? $('<div>').append(tree.get_node(obj).clone()).html() : tree.container.children("ul:eq(0)").html();
				},
				parse	: function(data, tree, opts, callback) {
					if(callback) callback.call(null, data);
					return data;
				},
				load	: function(data, tree, opts, callback) {
					if(opts.url) {
						$.ajax({
							'type'		: opts.method,
							'url'		: opts.url, 
							'data'		: data, 
							'dataType'	: "html",
							'success'	: function (d, textStatus) {
								callback.call(null, d);
							},
							'error'		: function (xhttp, textStatus, errorThrown) { 
								callback.call(null, false);
								tree.error(errorThrown + " " + textStatus); 
							}
						});
					}
					else {
						callback.call(null, opts.static || tree.container.children("ul:eq(0)").html());
					}
				}
			};
		},
		"json" : function () {
			return {
				get		: function(obj, tree, opts) { 
					var _this = this;
					if(!obj || $(obj).size() == 0) obj = tree.container.children("ul").children("li");
					else obj = $(obj);

					if(!opts) opts = {};
					if(!opts.outer_attrib) opts.outer_attrib = [ "id", "rel", "class" ];
					if(!opts.inner_attrib) opts.inner_attrib = [ ];

					if(obj.size() > 1) {
						var arr = [];
						obj.each(function () {
							arr.push(_this.get(this, tree, opts));
						});
						return arr;
					}
					if(obj.size() == 0) return [];

					var json = { attributes : {}, data : {} };
					if(obj.hasClass("open")) json.data.state = "open";
					if(obj.hasClass("closed")) json.data.state = "closed";

					for(var i in opts.outer_attrib) {
						if(!opts.outer_attrib.hasOwnProperty(i)) continue;
						var val = (opts.outer_attrib[i] == "class") ? obj.attr(opts.outer_attrib[i]).replace(/(^| )last( |$)/ig," ").replace(/(^| )(leaf|closed|open)( |$)/ig," ") : obj.attr(opts.outer_attrib[i]);
						if(typeof val != "undefined" && val.toString().replace(" ","").length > 0) json.attributes[opts.outer_attrib[i]] = val;
						delete val;
					}
					
					if(tree.settings.languages.length) {
						for(var i in tree.settings.languages) {
							if(!tree.settings.languages.hasOwnProperty(i)) continue;
							var a = obj.children("a." + tree.settings.languages[i]);
							if(opts.force || opts.inner_attrib.length || a.children("ins").get(0).style.backgroundImage.toString().length || a.children("ins").get(0).className.length) {
								json.data[tree.settings.languages[i]] = {};
								json.data[tree.settings.languages[i]].title = tree.get_text(obj,tree.settings.languages[i]);
								if(a.children("ins").get(0).style.className.length) {
									json.data[tree.settings.languages[i]].icon = a.children("ins").get(0).style.className;
								}
								if(a.children("ins").get(0).style.backgroundImage.length) {
									json.data[tree.settings.languages[i]].icon = a.children("ins").get(0).style.backgroundImage.replace("url(","").replace(")","");
								}
								if(opts.inner_attrib.length) {
									json.data[tree.settings.languages[i]].attributes = {};
									for(var j in opts.inner_attrib) {
										if(!opts.inner_attrib.hasOwnProperty(j)) continue;
										var val = a.attr(opts.inner_attrib[j]);
										if(typeof val != "undefined" && val.toString().replace(" ","").length > 0) json.data[tree.settings.languages[i]].attributes[opts.inner_attrib[j]] = val;
										delete val;
									}
								}
							}
							else {
								json.data[tree.settings.languages[i]] = tree.get_text(obj,tree.settings.languages[i]);
							}
						}
					}
					else {
						var a = obj.children("a");
						json.data.title = tree.get_text(obj);

						if(a.children("ins").size() && a.children("ins").get(0).className.length) {
							json.data.icon = a.children("ins").get(0).className;
						}
						if(a.children("ins").size() && a.children("ins").get(0).style.backgroundImage.length) {
							json.data.icon = a.children("ins").get(0).style.backgroundImage.replace("url(","").replace(")","");
						}

						if(opts.inner_attrib.length) {
							json.data.attributes = {};
							for(var j in opts.inner_attrib) {
								if(!opts.inner_attrib.hasOwnProperty(j)) continue;
								var val = a.attr(opts.inner_attrib[j]);
								if(typeof val != "undefined" && val.toString().replace(" ","").length > 0) json.data.attributes[opts.inner_attrib[j]] = val;
								delete val;
							}
						}
					}

					if(obj.children("ul").size() > 0) {
						json.children = [];
						obj.children("ul").children("li").each(function () {
							json.children.push(_this.get(this, tree, opts));
						});
					}
					return json;
				},
				parse	: function(data, tree, opts, callback) { 
					if(Object.prototype.toString.apply(data) === "[object Array]") {
						var str = '';
						for(var i = 0; i < data.length; i ++) {
							if(typeof data[i] == "function") continue;
							str += this.parse(data[i], tree, opts);
						}
						if(callback) callback.call(null, str);
						return str;
					}

					if(!data || !data.data) {
						if(callback) callback.call(null, false);
						return "";
					}

					var str = '';
					str += "<li ";
					var cls = false;
					if(data.attributes) {
						for(var i in data.attributes) {
							if(!data.attributes.hasOwnProperty(i)) continue;
							if(i == "class") {
								str += " class='" + data.attributes[i] + " ";
								if(data.state == "closed" || data.state == "open") str += " " + data.state + " ";
								str += "' ";
								cls = true;
							}
							else str += " " + i + "='" + data.attributes[i] + "' ";
						}
					}
					if(!cls && (data.state == "closed" || data.state == "open")) str += " class='" + data.state + "' ";
					str += ">";

					if(tree.settings.languages.length) {
						for(var i = 0; i < tree.settings.languages.length; i++) {
							var attr = {};
							attr["href"] = "";
							attr["style"] = "";
							attr["class"] = tree.settings.languages[i];
							if(data.data[tree.settings.languages[i]] && (typeof data.data[tree.settings.languages[i]].attributes).toLowerCase() != "undefined") {
								for(var j in data.data[tree.settings.languages[i]].attributes) {
									if(!data.data[tree.settings.languages[i]].attributes.hasOwnProperty(j)) continue;
									if(j == "style" || j == "class")	attr[j] += " " + data.data[tree.settings.languages[i]].attributes[j];
									else								attr[j]  = data.data[tree.settings.languages[i]].attributes[j];
								}
							}
							str += "<a";
							for(var j in attr) {
								if(!attr.hasOwnProperty(j)) continue;
								str += ' ' + j + '="' + attr[j] + '" ';
							}
							str += ">";
							if(data.data[tree.settings.languages[i]] && data.data[tree.settings.languages[i]].icon) {
								str += "<ins " + (data.data[tree.settings.languages[i]].icon.indexOf("/") == -1 ? " class='" + data.data[tree.settings.languages[i]].icon + "' " : " style='background-image:url(\"" + data.data[tree.settings.languages[i]].icon + "\");' " ) + ">&nbsp;</ins>";
							}
							else str += "<ins>&nbsp;</ins>";
							str += ( (typeof data.data[tree.settings.languages[i]].title).toLowerCase() != "undefined" ? data.data[tree.settings.languages[i]].title : data.data[tree.settings.languages[i]] ) + "</a>";
						}
					}
					else {
						var attr = {};
						attr["href"] = "";
						attr["style"] = "";
						attr["class"] = "";
						if((typeof data.data.attributes).toLowerCase() != "undefined") {
							for(var i in data.data.attributes) {
								if(!data.data.attributes.hasOwnProperty(i)) continue;
								if(i == "style" || i == "class")	attr[i] += " " + data.data.attributes[i];
								else								attr[i]  = data.data.attributes[i];
							}
						}
						str += "<a";
						for(var i in attr) {
							if(!attr.hasOwnProperty(i)) continue;
							str += ' ' + i + '="' + attr[i] + '" ';
						}
						str += ">";
						if(data.data.icon) {
							str += "<ins " + (data.data.icon.indexOf("/") == -1 ? " class='" + data.data.icon + "' " : " style='background-image:url(\"" + data.data.icon + "\");' " ) + ">&nbsp;</ins>";
						}
						else str += "<ins>&nbsp;</ins>";
						str += ( (typeof data.data.title).toLowerCase() != "undefined" ? data.data.title : data.data ) + "</a>";
					}
					if(data.children && data.children.length) {
						str += '<ul>';
						for(var i = 0; i < data.children.length; i++) {
							str += this.parse(data.children[i], tree, opts);
						}
						str += '</ul>';
					}
					str += "</li>";
					if(callback) callback.call(null, str);
					return str;
				},
				load	: function(data, tree, opts, callback) {
					if(opts.static) {
						callback.call(null, opts.static);
					} 
					else {
						$.ajax({
							'type'		: opts.method,
							'url'		: opts.url, 
							'data'		: data, 
							'dataType'	: "json",
							'success'	: function (d, textStatus) {
								callback.call(null, d);
							},
							'error'		: function (xhttp, textStatus, errorThrown) { 
								callback.call(null, false);
								tree.error(errorThrown + " " + textStatus); 
							}
						});
					}
				}
			}
		}
	});
})(jQuery);