(function ($) {
	$.extend($.tree.plugins, {
		"contextmenu" : {
			object : $("<ul id='jstree-contextmenu' class='tree-context' />"),
			data : {
				t : false,
				a : false,
				r : false
			},

			defaults : {
				class_name : "hover",
				items : {
					create : {
						label	: "Create", 
						icon	: "create",
						visible	: function (NODE, TREE_OBJ) { if(NODE.length != 1) return 0; return TREE_OBJ.check("creatable", NODE); }, 
						action	: function (NODE, TREE_OBJ) { TREE_OBJ.create(false, TREE_OBJ.get_node(NODE[0])); },
						separator_after : true
					},
					rename : {
						label	: "Rename", 
						icon	: "rename",
						visible	: function (NODE, TREE_OBJ) { if(NODE.length != 1) return false; return TREE_OBJ.check("renameable", NODE); }, 
						action	: function (NODE, TREE_OBJ) { TREE_OBJ.rename(NODE); } 
					},
					remove : {
						label	: "Delete",
						icon	: "remove",
						visible	: function (NODE, TREE_OBJ) { var ok = true; $.each(NODE, function () { if(TREE_OBJ.check("deletable", this) == false) ok = false; return false; }); return ok; }, 
						action	: function (NODE, TREE_OBJ) { $.each(NODE, function () { TREE_OBJ.remove(this); }); } 
					}
				}
			},
			show : function(obj, t) {
				var opts = $.extend(true, {}, $.tree.plugins.contextmenu.defaults, t.settings.plugins.contextmenu);
				obj = $(obj);
				$.tree.plugins.contextmenu.object.empty();
				var str = "";
				var cnt = 0;
				for(var i in opts.items) {
					if(!opts.items.hasOwnProperty(i)) continue;
					if(opts.items[i] === false) continue;
					var r = 1;
					if(typeof opts.items[i].visible == "function") r = opts.items[i].visible.call(null, $.tree.plugins.contextmenu.data.a, t);
					if(r == -1) continue;
					else cnt ++;
					if(opts.items[i].separator_before === true) str += "<li class='separator'><span>&nbsp;</span></li>";
					str += '<li><a href="#" rel="' + i + '" class="' + i + ' ' + (r == 0 ? 'disabled' : '') + '">';
					if(opts.items[i].icon) str += "<ins " + (opts.items[i].icon.indexOf("/") == -1 ? " class='" + opts.items[i].icon + "' " : " style='background-image:url(\"" + opts.items[i].icon + "\");' " ) + ">&nbsp;</ins>";
					else str += "<ins>&nbsp;</ins>";
					str += "<span>" + opts.items[i].label + '</span></a></li>';
					if(opts.items[i].separator_after === true) str += "<li class='separator'><span>&nbsp;</span></li>";
				}
				var tmp = obj.children("a:visible").offset();
				$.tree.plugins.contextmenu.object.attr("class","tree-context tree-" + t.settings.ui.theme_name.toString() + "-context").html(str);
				var h = $.tree.plugins.contextmenu.object.height();
				var w = $.tree.plugins.contextmenu.object.width();
				var x = tmp.left;
				var y = tmp.top + parseInt(obj.children("a:visible").height()) + 2;
				var max_y = $(window).height() + $(window).scrollTop();
				var max_x = $(window).width() + $(window).scrollLeft();
				if(y + h > max_y) y = Math.max( (max_y - h - 2), 0);
				if(x + w > max_x) x = Math.max( (max_x - w - 2), 0);
				$.tree.plugins.contextmenu.object.css({ "left" : (x), "top" : (y) }).fadeIn("fast");
			},
			hide : function () {
				if(!$.tree.plugins.contextmenu.data.t) return;
				var opts = $.extend(true, {}, $.tree.plugins.contextmenu.defaults, $.tree.plugins.contextmenu.data.t.settings.plugins.contextmenu);
				if($.tree.plugins.contextmenu.data.r && $.tree.plugins.contextmenu.data.a) {
					$.tree.plugins.contextmenu.data.a.children("a, span").removeClass(opts.class_name);
				}
				$.tree.plugins.contextmenu.data = { a : false, r : false, t : false };
				$.tree.plugins.contextmenu.object.fadeOut("fast");
			},
			exec : function (cmd) {
				if($.tree.plugins.contextmenu.data.t == false) return;
				var opts = $.extend(true, {}, $.tree.plugins.contextmenu.defaults, $.tree.plugins.contextmenu.data.t.settings.plugins.contextmenu);
				try { opts.items[cmd].action.apply(null, [$.tree.plugins.contextmenu.data.a, $.tree.plugins.contextmenu.data.t]); } catch(e) { };
			},

			callbacks : {
				oninit : function () {
					if(!$.tree.plugins.contextmenu.css) {
						var css = '#jstree-contextmenu { display:none; position:absolute; z-index:2000; list-style-type:none; margin:0; padding:0; left:-2000px; top:-2000px; } .tree-context { margin:20px; padding:0; width:180px; border:1px solid #979797; padding:2px; background:#f5f5f5; list-style-type:none; }.tree-context li { height:22px; margin:0 0 0 27px; padding:0; background:#ffffff; border-left:1px solid #e0e0e0; }.tree-context li a { position:relative; display:block; height:22px; line-height:22px; margin:0 0 0 -28px; text-decoration:none; color:black; padding:0; }.tree-context li a ins { text-decoration:none; float:left; width:16px; height:16px; margin:0 0 0 0; background-color:#f0f0f0; border:1px solid #f0f0f0; border-width:3px 5px 3px 6px; line-height:16px; }.tree-context li a span { display:block; background:#f0f0f0; margin:0 0 0 29px; padding-left:5px; }.tree-context li.separator { background:#f0f0f0; height:2px; line-height:2px; font-size:1px; border:0; margin:0; padding:0; }.tree-context li.separator span { display:block; margin:0px 0 0px 27px; height:1px; border-top:1px solid #e0e0e0; border-left:1px solid #e0e0e0; line-height:1px; font-size:1px; background:white; }.tree-context li a:hover { border:1px solid #d8f0fa; height:20px; line-height:20px; }.tree-context li a:hover span { background:#e7f4f9; margin-left:28px; }.tree-context li a:hover ins { background-color:#e7f4f9; border-color:#e7f4f9; border-width:2px 5px 2px 5px; }.tree-context li a.disabled { color:gray; }.tree-context li a.disabled ins { }.tree-context li a.disabled:hover { border:0; height:22px; line-height:22px; }.tree-context li a.disabled:hover span { background:#f0f0f0; margin-left:29px; }.tree-context li a.disabled:hover ins { border-color:#f0f0f0; background-color:#f0f0f0; border-width:3px 5px 3px 6px; }';
						$.tree.plugins.contextmenu.css = this.add_sheet({ str : css });
					}
				},
				onrgtclk : function (n, t, e) {
					var opts = $.extend(true, {}, $.tree.plugins.contextmenu.defaults, t.settings.plugins.contextmenu);
					n = $(n);
					if(n.size() == 0) return;
					$.tree.plugins.contextmenu.data.t = t;
					if(!n.children("a:eq(0)").hasClass("clicked")) {
						$.tree.plugins.contextmenu.data.a = n;
						$.tree.plugins.contextmenu.data.r = true;
						n.children("a").addClass(opts.class_name);
						e.target.blur();
					}
					else { 
						$.tree.plugins.contextmenu.data.r = false; 
						$.tree.plugins.contextmenu.data.a = (t.selected_arr && t.selected_arr.length > 1) ? t.selected_arr : t.selected;
					}
					$.tree.plugins.contextmenu.show(n, t);
					e.preventDefault(); 
					e.stopPropagation();
					// return false; // commented out because you might want to do something in your own callback
				},
				onchange : function () { $.tree.plugins.contextmenu.hide(); },
				beforedata : function () { $.tree.plugins.contextmenu.hide(); },
				ondestroy : function () { $.tree.plugins.contextmenu.hide(); }
			}
		}
	});
	$(function () {
		$.tree.plugins.contextmenu.object.hide().appendTo("body");
		$("#jstree-contextmenu a")
			.live("click", function (event) {
				if(!$(this).hasClass("disabled")) {
					$.tree.plugins.contextmenu.exec.apply(null, [$(this).attr("rel")]);
					$.tree.plugins.contextmenu.hide();
				}
				event.stopPropagation();
				event.preventDefault();
				return false;
			})
		$(document).bind("mousedown", function(event) { if($(event.target).parents("#jstree-contextmenu").size() == 0) $.tree.plugins.contextmenu.hide(); });
	});
})(jQuery);