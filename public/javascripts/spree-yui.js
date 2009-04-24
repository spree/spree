/* spree YUI support stuffs */
spree.YUI = {
  registered_trees: {},
	inplace_editors: [],
	drag_objects: [],
	drop_objects: [],
	goingUp: false,
	lastY:0,
	drag_parent:null,
	drag_node:null,
	drag_text:null,
	
  new_node: function() { 
		var target = spree.YUI.current_tree.current_target;
		var tree = spree.YUI.current_tree;
		
		var rand_no = Math.ceil(1000000 * Math.random());
		var node_config = {id: 'new_taxon_node_' + rand_no, html:'<span id="new_taxon_node_' + rand_no + '" class="spree-YUI-tree-node">New Taxon</span>', parent_id: target.data.id}

		var HTMLnode = spree.YUI.initialize_node(tree, node_config);
		
		//refresh the tree and reattach all inplace editors
		if(target.expanded) {
			target.collapse();
			target.expand();
		} else {
			target.expand();
		}
		target.refresh();
		spree.YUI.register_inplace_controls();

		var target_url = target.data.object_url.split('/');
 		var parent_id = target_url.last();
		target_url = target_url.slice(0, (target_url.length - 1))
				
		//add inplace creator
		var ipe = new Ajax.InPlaceEditor('new_taxon_node_' + rand_no, target_url.join('/'), {
				callback: function(form, value) { return 'taxon[name]=' + encodeURIComponent(value) + '&taxon[parent_id]=' + encodeURIComponent(parent_id)},  	
				onComplete: function(transport, element) {
						if (transport){
							//got response from server
							var new_taxon = transport.responseText.evalJSON().taxon;
				 			var tree = spree.YUI.current_tree;
									
							//destory inplace creator
							spree.YUI.remove_inplace_control(element.id);

							var node = tree.tree_view.getNodeByProperty('id', element.id);
							node.data.id = new_taxon.id;
							node.data.object_url = this.url + '/' + new_taxon.id;
							node.data.position = new_taxon.position;
							node.html = '<span id="node_' + new_taxon.id + '" class="spree-YUI-tree-node">' + new_taxon.name + '</span>&nbsp;<img src="/images/spinner.gif" style="display:none;vertical-align:middle;" id="taxon_' +  new_taxon.id + '">';
		
							//refresh the tree and reattach all inplace editors
							node.parent.refresh();
							spree.YUI.register_inplace_controls();
							
							//add inplace editor & drag / drop
							spree.YUI.inplace_editors[spree.YUI.inplace_editors.length] = new Ajax.InPlaceEditor('node_' + new_taxon.id, node.data.object_url, {
								callback: function(form, value) { return 'taxon[name]=' + encodeURIComponent(value) }, 
								onComplete: spree.YUI.after_inplace_edit, 
								savingText: 'Saving...&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;', 
								textBetweenControls: ' or ',      
								ajaxOptions: {method: 'put'}
							});
							var ddp = new YAHOO.util.DDProxy('node_' + new_taxon.id);
							ddp = spree.YUI.register_drag_events(ddp);
							spree.YUI.drag_objects[spree.YUI.drag_objects.length] = ddp;
							spree.YUI.drop_objects[spree.YUI.drop_objects.length] = new YAHOO.util.DDTarget('node_' + new_taxon.id);
						}else{
							//no response from server (user clicked cancel)
							
						}
				},
				savingText: 'Adding...&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
				textBetweenControls: ' or ',
				ajaxOptions: {method: 'post'}});
 
		spree.YUI.inplace_editors[spree.YUI.inplace_editors.length] = ipe;
		
		//get the newly created node, and force the onclick event, to display the inplace creator
		spree.YUI.fire_event($('new_taxon_node_' + rand_no), 'click');
		
		var form = $('new_taxon_node_' + rand_no + '-inplaceeditor');
		var cancel_link = form.select('.editor_cancel_link')[0];
		
		//delete node again if user cancels before saving.
		cancel_link.observe('click', function(event){
			var parent = HTMLnode.parent
			tree.tree_view.removeNode(HTMLnode, true)
			spree.YUI.remove_inplace_control(HTMLnode.data.id)
			if(parent.children.length==0) parent.collapse();
			parent.refresh();
			spree.YUI.register_inplace_controls();
		});
		
		
  },

  edit_node: function() { 
		var target = spree.YUI.current_tree.current_target;
		
		var span =	$('node_' + target.data.id);
		spree.YUI.fire_event(span, 'click');
  },

  delete_node: function() { 
		var tree = spree.YUI.current_tree;
		var target = spree.YUI.current_tree.current_target;
		var url = target.data.object_url;

		if (confirm('Are you sure that you want to delete this taxon?')){
		  new Ajax.Request(url, {
		  	method: 'post',
		  	parameters: {_method: 'delete'},
				onSuccess: function(transport){
					var parent = target.parent
					//remove node
					tree.tree_view.removeNode(target, true)
					
					//destory inplace editor
					spree.YUI.remove_inplace_control('node_' + target.data.id)
					
					//refresh the tree and reattach all inplace editors
					if(parent.children.length==0) parent.collapse();
					parent.refresh();
					spree.YUI.register_inplace_controls();
				 
				},
				onLoading: function(){
					Element.show('taxon_' + target.data.id)
				}
		  });
		}

  },

  move_node_up: function() { 	
		var tree = spree.YUI.current_tree;
		var target = spree.YUI.current_tree.current_target;
		var url = target.data.object_url;

	  new Ajax.Request(url, {
		 	method: 'post',
		 	parameters: '_method=put&taxon[position]=' + (target.data.position - 1),
			onLoading: function(){
				Element.show('taxon_' + target.data.id)
			},
			onSuccess: function(transport){				
				Element.hide('taxon_' + target.data.id)
				target.data.position = (target.data.position - 1);
				var parent = target.parent;
				tree.tree_view.popNode(target);

				parent.children.each(function(node) { 
 					if(node.data.position==target.data.position){
						node.data.position = (target.data.position + 1);
												
						target.insertBefore(node);
						node.parent.refresh();
						
						spree.YUI.register_inplace_controls();
						throw $break;
					}
	 
				});
				
			}
	  });
  },

	move_node_down: function() { 
		var tree = spree.YUI.current_tree;
		var target = spree.YUI.current_tree.current_target;
		var url = target.data.object_url;
 	
	  new Ajax.Request(url, {
		 	method: 'post',
		 	parameters: '_method=put&taxon[position]=' + (target.data.position + 1),
			onLoading: function(){
				Element.show('taxon_' + target.data.id)
			},
			onSuccess: function(transport){
				Element.hide('taxon_' + target.data.id)
				target.data.position = (target.data.position + 1);
		
				var parent = target.parent;
				tree.tree_view.popNode(target); 
		
				parent.children.each(function(node) { 
 
					if(node.data.position==target.data.position){
						node.data.position = (target.data.position - 1);
											
						target.insertAfter(node);
						node.parent.refresh();
					
						spree.YUI.register_inplace_controls();
						throw $break;
					}
	 
				});
				
 
			}
	  });
  },

	cut_node: function() {
		var tree = spree.YUI.current_tree;
		var target = spree.YUI.current_tree.current_target;
		
		spree.YUI.drag_node = target;
		spree.YUI.drag_parent = target.parent;
		if (tree.tree_view.getNodeByProperty('id', target.data.id)) tree.tree_view.popNode(target);
 		if (spree.YUI.drag_parent.children.length==0) spree.YUI.drag_parent.collapse();

		tree.tree_view.root.refresh(); 
		spree.YUI.register_inplace_controls();
	},
	
	paste_node: function() {
		var tree = spree.YUI.current_tree;
		var target = spree.YUI.current_tree.current_target;
		
		var count = target.children.length
		
		var paste_node = spree.YUI.drag_node;
		paste_node.appendTo(target);
 		if (!target.expanded) target.expand();
		
		tree.tree_view.root.refresh(); 
		spree.YUI.register_inplace_controls();
		
		var url = paste_node.data.object_url;
		
		if(target.data.id==spree.YUI.drag_parent.data.parent_id){
			//being pasted onto same parent
		} 
			console.log(count)

		new Ajax.Request(url, {
		 	method: 'post',
		 	parameters: '_method=put&taxon[parent_id]=' + encodeURIComponent(target.data.id) + '&taxon[position]=' + count,
			onLoading: function(){
				Element.show('taxon_' + paste_node.data.id)
			},
			onSuccess: function(transport){
				Element.hide('taxon_' + paste_node.data.id)

				paste_node.data.parent_id = target.data.id;
				paste_node.data.position = count	;
			}
		});
		
		spree.YUI.drag_node = null;
		spree.YUI.drag_parent = null;
	},

	fire_event: function(obj, event){
		if (document.createEventObject){
        // dispatch for IE
        var evt = document.createEventObject();
        return obj.fireEvent('on'+event,evt)
    }
    else{
        // dispatch for firefox + others
		   var evt = document.createEvent("HTMLEvents");
		   evt.initEvent(event, true, true ); // event type,bubbling,cancelable
		   obj.dispatchEvent(evt);
    }
	},

  onTriggerContextMenu: function(p_sType, p_Args) { 
		var event = p_Args[0]; 
		var node = YAHOO.util.Event.getTarget(event);

		// find the target which is a tree node 
		var target = YAHOO.util.Dom.hasClass(node, 'ygtvhtml') 
		? node 
		: YAHOO.util.Dom.getAncestorByClassName(node, 'ygtvhtml'); 
 
		if (target) { 
		  var tree = spree.YUI.set_current_target(target);	
			this.clearContent();
		 	var items = {};
		
		  if (spree.YUI.current_tree.current_target == tree.root) {
				items = [{ text: "New Child", onclick: { fn: spree.YUI.new_node } } ]  
		  } else {
			 	items = [ 
					{ text: "New Child", onclick: { fn: spree.YUI.new_node } }, 
					{ text: "Edit", onclick: { fn: spree.YUI.edit_node } },
					{ text: "Delete", onclick: { fn: spree.YUI.delete_node } }, 
					{ text: "Cut", onclick: { fn: spree.YUI.cut_node } }];
			}	
			
			if(spree.YUI.drag_node){
				items[items.length] = { text: "Paste", onclick: { fn: spree.YUI.paste_node } }
			}
			
			var node_id = node.id.gsub('node_', '');
			node = tree.tree_view.getNodeByProperty('id',node_id);
			if(Object.isUndefined(node)){
				//inplace editing, drop submenu
				items = {};
			}else{
				if(node.previousSibling!=null){
					items[items.length] = { text: "Move Up", onclick: { fn: spree.YUI.move_node_up } }
				}
				if(node.nextSibling!=null){
					items[items.length] = { text: "Move Down", onclick: { fn: spree.YUI.move_node_down } }
				}
			}
 
			
			this.itemData = items;
			this.init();
		}	
  },
  
  build_tree: function(container_element_id, tree_data) {
		var tree = spree.YUI.registered_trees[container_element_id];
		if (tree) {
		  spree.YUI.destroy_tree(tree);
		}

		tree = {};
		spree.YUI.register_tree(tree, container_element_id, "taxonomy_tree");

		tree.tree_view = new YAHOO.widget.TreeView(container_element_id);

		for (var i = 0; i < tree_data.length; i++) {
			spree.YUI.initialize_node(tree, tree_data[i]);
		}
	
		// This hack does not make me happy
		var rand_no = Math.ceil(1000000 * Math.random());
		tree.context_menu = new YAHOO.widget.ContextMenu("cm_" + container_element_id + '_' + rand_no, 
														 { trigger: container_element_id, 
															 lazyload: true,  
															 itemdata: {} }); 
	
		tree.context_menu.subscribe("triggerContextMenu", spree.YUI.onTriggerContextMenu ); 
 
		return tree;
  },

	add_inplace_controls: function(tree_data){
		//add drop control for root node
		spree.YUI.drop_objects[spree.YUI.drop_objects.length] = new YAHOO.util.DDTarget('node_' + tree_data[0].id);
		
		//add inplace editor and drag/drop controls
		for (var i = 1; i < tree_data.length; i++) {
			spree.YUI.inplace_editors[spree.YUI.inplace_editors.length] = new Ajax.InPlaceEditor('node_' + tree_data[i].id, tree_data[i].object_url, {
					callback: function(form, value) { return 'taxon[name]=' + encodeURIComponent(value) }, 
					onComplete: spree.YUI.after_inplace_edit,
					textBetweenControls: ' or ',
					savingText: 'Saving...&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;', 
					ajaxOptions: {method: 'put'}
			});
			
			var ddp = spree.YUI.register_drag_events(new YAHOO.util.DDProxy('node_' + tree_data[i].id));
			
			spree.YUI.drag_objects[spree.YUI.drag_objects.length] = ddp;
			spree.YUI.drop_objects[spree.YUI.drop_objects.length] = new YAHOO.util.DDTarget('node_' + tree_data[i].id);
  
		}
	},
	
	register_inplace_controls: function(){
		spree.YUI.inplace_editors.each(function(ipe) {
 			var element = $(ipe.element.id);
	 
 			if (element!=null) ipe.initialize(element, ipe.url, ipe.options);
		});
		
		spree.YUI.drag_objects = spree.YUI.drag_objects.collect(function(ddp, i) { 
	 		return spree.YUI.register_drag_events( new YAHOO.util.DDProxy(ddp.id));
		});
			
		spree.YUI.drop_objects =	spree.YUI.drop_objects.each(function(dd, i) {
 			return new YAHOO.util.DDTarget(dd.id);
		});
		
	},
	
	register_drag_events: function(ddp){
		ddp.onDragDrop = spree.YUI.onDragDrop;
		ddp.startDrag = spree.YUI.startDrag;
		
		ddp.onDragOut = spree.YUI.onDragOut;
		ddp.onDragOver = spree.YUI.onDragOver;
	 
		ddp.endDrag = spree.YUI.endDrag;
		ddp.onDrag = spree.YUI.onDrag;
		
		ddp.onInvalidDrop = spree.YUI.onInvalidDrop;
		
		return ddp;
	},
	
	remove_inplace_control: function(element_id){
		var ipe = spree.YUI.inplace_editors.find(function(n) { return n.element.id == element_id })
		ipe.destroy();
		spree.YUI.inplace_editors.splice(spree.YUI.inplace_editors.indexOf(ipe), 1);
		
	},

	after_inplace_edit: function(transport, element) {
		if (transport){
			//got response from server
			var tree = spree.YUI.find_tree_by_element(element);

			var node = tree.tree_view.getNodeByProperty('id', element.id.gsub('node_', ''));
			node.html = '<span id="' + element.id + '" class="spree-YUI-tree-node">' + transport.responseText + '</span>&nbsp;<img src="/images/spinner.gif" style="display:none;vertical-align:middle;" id="taxon_' + element.id.gsub('node_', '') + '">';
		}
	},
 
  initialize_node: function(tree, node) {
		var parent_node = node.parent_id == null 
		? tree.tree_view.getRoot() 
		: tree.tree_view.getNodeByProperty('id', node.parent_id);
		
		var HTMLnode = new YAHOO.widget.HTMLNode(node, parent_node, false, true);
		HTMLnode.renderHidden=true;
		if (node.parent_id == null){
			 tree.root = tree.tree_view.getNodeByProperty('id', node.id);
			 if(!tree.root.expanded) tree.root.expand();
		}
		return HTMLnode;
  },

  set_current_target: function(target) {
		var tree = spree.YUI.find_tree_by_element(target);
		tree.current_target = null; 
		var spree_target = YAHOO.util.Dom.getElementsByClassName('spree-YUI-tree-node','span',target)
		
		var target_id = spree_target[0].id;
		if(target_id.include('new_taxon_node_')){
			tree.current_target = tree.tree_view.getNodeByProperty('id', target_id);
		}else{
			tree.current_target = tree.tree_view.getNodeByProperty('id',target_id.gsub('node_', ''));
		}
				
		spree.YUI.current_tree = tree;
		return tree;
  },

  reset_current_target: function(target) {
		spree.YUI.current_tree = null;
  },

  find_tree_by_element: function(el) {
		var container = YAHOO.util.Dom.getAncestorByClassName(el, 'spree-YUI-tree-container');
		var tree = spree.YUI.registered_trees[container.id];
		return tree;
  },

  register_tree: function(tree, id, type) {
		var container = YAHOO.util.Dom.get(id);
		tree.id = id;
		YAHOO.util.Dom.addClass(id, 'spree-YUI-tree-container');

		spree.YUI.registered_trees[id] = tree;
		//  spree.YUI.registered_trees[type] = new Array();
		//  spree.YUI.registered_trees[type].push(tree);
  },

  destroy_tree: function(tree) {
		// unsubscribe menu
		tree.context_menu.unsubscribe("triggerContextMenu", spree.YUI.onTriggerContextMenu);
		delete tree.context_menu;

		// unregister tree
		delete spree.YUI.registered_trees[tree.id];

		// destroy tree view
		delete tree.tree_view;
  },

  onload: function() {
  },

	onDragDrop: function(e, id) {	
		if(!spree.YUI.drag_node) return

		var dragged_node = spree.YUI.drag_node;

		var tree = dragged_node.tree;
		var temp_node = tree.getNodeByProperty('id', 'temp_node');
		
		var data = dragged_node.data;
		var n = $('node_' + dragged_node.data.id);
		n.style.color='#000';
		n.style.backgroundColor='#fff'
	 	dragged_node.setHtml(n.up().innerHTML);
		dragged_node.data = data;
		
		var old_parent = dragged_node.data.parent_id;
		
		//remove from previous location
		if (tree.getNodeByProperty('id', dragged_node.data.id)) tree.popNode(dragged_node);
		if (spree.YUI.drag_parent.children.length==0) spree.YUI.drag_parent.collapse();
 
		//render node in correct location 
		dragged_node.data.parent_id = temp_node.parent.data.id;
		dragged_node.insertBefore(temp_node);
		tree.removeNode(temp_node);
		tree.root.refresh();  	
 
		//get position of node
		var position = 0;

		//get actual position of dropped node
		dragged_node.parent.children.each(function(node) { 
			if(node.data.id != dragged_node.data.id){
				position = position + 1;
			}else{
				throw $break;
			}
		});
		
		//reset all nodes to correct values
		var i = 0;
		dragged_node.parent.children.each(function(node) { 
 			node.data.position = i;
			i = i + 1;
		});
 
		var url = dragged_node.data.object_url;
		var params = '_method=put&taxon[position]=' + position;
 
		if(old_parent != dragged_node.data.parent_id){
			params = params + '&taxon[parent_id]=' + encodeURIComponent(dragged_node.parent.data.id)
		}
		
		new Ajax.Request(url, {
		 	method: 'post',
		 	parameters: params,
			onLoading: function(){
				Element.show('taxon_' + dragged_node.data.id)
			},
			onSuccess: function(transport){
				Element.hide('taxon_' + dragged_node.data.id)

				dragged_node.data.parent_id = drop_node.data.id;
				dragged_node.data.position = position;
				
				if(old_parent.children.length==0) old_parent.collapse();

			}
		});

		spree.YUI.register_inplace_controls();
		spree.YUI.drag_node = null;
		spree.YUI.drag_parent = null;
	},

	startDrag: function(x, y) {
		var dragEl = this.getDragEl();
		var clickEl = this.getEl();
		if(!clickEl) return
		
		var tree = spree.YUI.find_tree_by_element(clickEl);	
		spree.YUI.current_tree = tree;
		
		target = tree.tree_view.getNodeByProperty('id', clickEl.id.gsub('node_', ''));
		spree.YUI.drag_node = target;
		spree.YUI.drag_text = clickEl.textContent;
		spree.YUI.drag_parent = target.parent;

		var data = target.data;
		var n = $('node_' + target.data.id);
		n.style.color='#ccc';
		n.style.backgroundColor='#fff'
	 	target.setHtml(n.up().innerHTML);
 		target.data = data;

		dragEl.innerHTML = '&nbsp;&nbsp;&nbsp;&nbsp;';
		dragEl.style.border = 'none';
		var ddp = spree.YUI.register_drag_events(new YAHOO.util.DDProxy(dragEl));
	},
 	onDragOut: function(e, id){
		var tree = spree.YUI.drag_node.tree;		
		spree.YUI.drop_temp_node(tree);
		
		tree.root.refresh();
		spree.YUI.register_inplace_controls();				
	}, 
	onDragOver: function(e, id) {
			if(id=='temp_node') return
			if(!id.include('node')) return
	    var el;

	    if ("string" == typeof id) {
	        el = YAHOO.util.DDM.getElement(id);
	    } else {
	        el = YAHOO.util.DDM.getBestMatch(id).getEl();
	    }
	 		
			if(!el) return
 
			var tree = spree.YUI.find_tree_by_element(el);
			spree.YUI.current_tree = tree;
			
 			var hover_node = tree.tree_view.getNodeByProperty('id', el.id.gsub('node_', ''));
			
			var node_config = {id: 'temp_node', html:'<span id="temp_node" class="spree-YUI-tree-node" style="color:green;font-weight:bold;	">' + spree.YUI.drag_text + '</span>'}
			temp_node = new YAHOO.widget.HTMLNode(node_config, null, false, true);
			
			if (spree.YUI.goingUp) {  		
				spree.YUI.drop_temp_node(tree.tree_view);	
				
				if(hover_node.index==1){
					//hovering over root, can only insert as child
					if(hover_node.children.length>0){
						temp_node.insertBefore(hover_node.children[0]);
					}else{
						temp_node.appendTo(hover_node);
					}
				} else {
					temp_node.insertBefore(hover_node);
				}

			}else{
				if(hover_node.children.length>0){
		
					spree.YUI.drop_temp_node(tree.tree_view);	
					
					if(hover_node.expanded){		
						temp_node.insertBefore(hover_node.children[0]);
					} else {
						temp_node.insertAfter(hover_node);
					}
				}else{		
						spree.YUI.drop_temp_node(tree.tree_view);							
						temp_node.insertAfter(hover_node);
				}			
			}

			tree.tree_view.root.refresh();
			spree.YUI.register_inplace_controls();
 	
	},

	onDrag: function(e) { 
	 
   		// Keep track of the direction of the drag for use during onDragOver 
		var y = YAHOO.util.Event.getPageY(e); 

		if (y < spree.YUI.lastY) { 
		    spree.YUI.goingUp = true; 
		} else if (y > spree.YUI.lastY) { 
		    spree.YUI.goingUp = false; 
		} 
	 
		spree.YUI.lastY = y; 
	},

	endDrag: function(e) {
	   // override so source object doesn't move when we are done
	},
	
	onInvalidDrop: function(e) {
		var dragged_node = spree.YUI.drag_node;
		
		var data = dragged_node.data;
		var n = $('node_' + dragged_node.data.id);
		n.style.color='#000';
		n.style.backgroundColor='#fff'
	 	dragged_node.setHtml(n.up().innerHTML);
		dragged_node.data = data;
		
		var tree = spree.YUI.current_tree;
		spree.YUI.drop_temp_node(tree.tree_view);
		
		tree.tree_view.root.refresh();
		spree.YUI.register_inplace_controls();
		
		spree.YUI.drag_node = null;
		spree.YUI.drag_parent = null;
		
	},
	
	drop_temp_node: function(tree) {
		var rm = tree.getNodeByProperty('id', 'temp_node');
		if(rm) tree.removeNode(rm, false);
	}

}; // end spree.YUI namespace


