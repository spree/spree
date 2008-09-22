/* spree YUI support stuffs */
spree.YUI = {
  registered_trees: {},
	inplace_editors: [],
	drag_objects: [],
	drop_objects: [],
	
  new_node: function() { 
		var target = spree.YUI.current_tree.current_target;
		
		var rand_no = Math.ceil(1000000 * Math.random());
		var node_config = {id: 'new_taxon_node_' + rand_no, html:'<span id="new_taxon_node_' + rand_no + '" class="spree-YUI-tree-node">New Taxon</span>', parent_id: target.data.id}

		var HTMLnode = spree.YUI.initialize_node(tree, node_config);
		
		//refresh the tree and reattach all inplace editors
		if(!target.expanded) target.expand();
		target.refresh();
		spree.YUI.register_inplace_controls();

		var target_url = target.data.object_url.split('/');
 		var parent_id = target_url.last();
		target_url = target_url.without(parent_id);
		
		//add inplace creator
		var ipe = new Ajax.InPlaceEditor('new_taxon_node_' + rand_no, target_url.join('/'), {
				callback: function(form, value) { return 'taxon[name]=' + encodeURIComponent(value) + '&taxon[parent_id]=' + encodeURIComponent(parent_id)}, 
				onComplete: function(transport, element) {
						if (transport){
							//got response from server
							var new_taxon = transport.responseText.evalJSON();
				 			var tree = spree.YUI.current_tree;
									
							//destory inplace creator
							spree.YUI.remove_inplace_control(element.id);

							var node = tree.node_map[element.id];
							node.data.id = new_taxon.id;
							node.data.object_url = this.url + '/' + new_taxon.id;
							node.html = '<span id="node_' + new_taxon.id + '" class="spree-YUI-tree-node">' + new_taxon.name + '</span>&nbsp;<img src="/images/spinner.gif" style="display:none;vertical-align:middle;" id="taxon_' +  new_taxon.id + '">';
							tree.node_map[new_taxon.id] = node;
		
							//refresh the tree and reattach all inplace editors
							node.parent.refresh();
							spree.YUI.register_inplace_controls();
							
							//add inplace editor
							spree.YUI.inplace_editors[spree.YUI.inplace_editors.length] = new Ajax.InPlaceEditor('node_' + new_taxon.id, node.data.object_url, {callback: function(form, value) { return 'taxon[name]=' + encodeURIComponent(value) }, onComplete: spree.YUI.after_inplace_edit, savingText: 'Saving...&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;', ajaxOptions: {method: 'put'}});
						}else{
							//no response from server (user clicked cancel)
							
						}
				},
				savingText: 'Adding...&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',
				ajaxOptions: {method: 'post'}});
		
		spree.YUI.inplace_editors[spree.YUI.inplace_editors.length] = ipe;
		
		//get the newly created node, and force the onclick event, to display the inplace creator
 	 	var span =	$('new_taxon_node_' + rand_no);
		
		spree.YUI.fire_event(span, 'click');
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
					parent.refresh();
					spree.YUI.register_inplace_controls();
				 
				},
				onLoading: function(){
					Element.show('taxon_' + target.data.id)
				}
		  });
		}

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
		var target = YAHOO.util.Event.getTarget(event);

		// find the target which is a tree node 
		target = YAHOO.util.Dom.hasClass(target, 'ygtvhtml') 
		? target 
		: YAHOO.util.Dom.getAncestorByClassName(target, 'ygtvhtml'); 
 
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
					{ text: "Delete", onclick: { fn: spree.YUI.delete_node } } ];
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
		tree.node_map = {};

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
		for (var i = 1; i < tree_data.length; i++) {
			spree.YUI.inplace_editors[spree.YUI.inplace_editors.length] = new Ajax.InPlaceEditor('node_' + tree_data[i].id, tree_data[i].object_url, {
					callback: function(form, value) { return 'taxon[name]=' + encodeURIComponent(value) }, 
					onComplete: spree.YUI.after_inplace_edit,
					savingText: 'Saving...&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;', 
					ajaxOptions: {method: 'put'}
			});
			
			spree.YUI.drag_objects[spree.YUI.drag_objects.length] = new YAHOO.util.DD('node_' + tree_data[i].id);
			spree.YUI.drop_objects[spree.YUI.drop_objects.length] = new DDSend('node_' + tree_data[i].id);
  
		}
	},
	
	register_inplace_controls: function(){
		spree.YUI.inplace_editors.each(function(ipe) {
			ipe.destroy();
			ipe.initialize(ipe.element.id, ipe.url, ipe.options);
		});
		
		spree.YUI.drag_objects.each(function(dd) { 
			dd.unreg();
			dd = new YAHOO.util.DD(dd.id);  
		});
			
		spree.YUI.drag_objects.each(function(dd) {
 			dd.unreg();
			dd = new DDSend(dd.id);
		});
		
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

			var node = tree.node_map[element.id.gsub('node_', '')];
			node.html = '<span id="' + element.id + '" class="spree-YUI-tree-node">' + transport.responseText + '</span>&nbsp;<img src="/images/spinner.gif" style="display:none;vertical-align:middle;" id="taxon_' + element.id.gsub('node_', '') + '">';
		}
	},
 
  initialize_node: function(tree, node) {
		var parent_node = node.parent_id == null 
		? tree.tree_view.getRoot() 
		: tree.node_map[node.parent_id];
		
		var HTMLnode = new YAHOO.widget.HTMLNode(node, parent_node, false, true);
		HTMLnode.renderHidden=true;
		tree.node_map[node.id] = HTMLnode;
		if (node.parent_id == null) tree.root = tree.node_map[node.id];
		
		return HTMLnode;
  },

  set_current_target: function(target) {
		var tree = spree.YUI.find_tree_by_element(target);
		tree.current_target = null; 
		var spree_target = YAHOO.util.Dom.getElementsByClassName('spree-YUI-tree-node','span',target)
		
		var target_id = spree_target[0].id;
		if(target_id.include('new_taxon_node_')){
			tree.current_target = tree.node_map[target_id];
		}else{
			tree.current_target = tree.node_map[target_id.gsub('node_', '')];
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
		// uninitialize nodes
		for (var i=0; i<tree.node_map.length; i++) {
		  delete tree.node_map[i];
		}
		delete tree.node_map;

		// unsubscribe menu
		tree.context_menu.unsubscribe("triggerContextMenu", spree.YUI.onTriggerContextMenu);
		delete tree.context_menu;

		// unregister tree
		delete spree.YUI.registered_trees[tree.id];

		// destroy tree view
		delete tree.tree_view;
  },

  onload: function() {
  }

}; // end spree.YUI namespace

DDSend = function(id, sGroup, config) {

    if (id) {
        // bind this drag drop object to the
        // drag source object
        this.init(id, sGroup, config);
        this.initFrame();
    }

    var s = this.getDragEl().style;
    s.borderColor = "transparent";
    s.backgroundColor = "#f6f5e5";
    s.opacity = 0.76;
    s.filter = "alpha(opacity=76)";
};

// extend proxy so we don't move the whole object around
DDSend.prototype = new YAHOO.util.DDProxy();

DDSend.prototype.onDragDrop = function(e, id) {
		var target = this._domRef;
		target = YAHOO.util.Dom.hasClass(target, 'ygtvhtml') 
		? target 
		: YAHOO.util.Dom.getAncestorByClassName(target, 'ygtvhtml'); 
 
		var tree = spree.YUI.set_current_target(target);
		
		var dragged_node = tree.node_map[this.id.gsub('node_', '')];
		var drop_node = tree.node_map[id.gsub('node_', '')];
		
		tree.tree_view.removeNode(dragged_node, true)
		
		dragged_node.appendTo(drop_node);
		if(!drop_node.expanded) drop_node.expand();
		drop_node.refresh();
		
		var url = dragged_node.data.object_url;
		
		new Ajax.Request(url, {
		 	method: 'post',
		 	parameters: '_method=put&taxon[parent_id]=' + encodeURIComponent(drop_node.data.id),
			onLoading: function(){
				Element.show('taxon_' + dragged_node.data.id)
			},
			onSuccess: function(transport){
				Element.hide('taxon_' + dragged_node.data.id)
			}
		});
		
		spree.YUI.register_inplace_controls();
}

DDSend.prototype.startDrag = function(x, y) {
    // called when source object first selected for dragging
    // draw a red border around the drag object we create
    var dragEl = this.getDragEl();
    var clickEl = this.getEl();

    dragEl.innerHTML = clickEl.innerHTML;
    dragEl.className = clickEl.className;
    dragEl.style.color = clickEl.style.color;
    dragEl.style.border = "1px solid red";

};

DDSend.prototype.onDragEnter = function(e, id) {
    var el;

    // this is called anytime we drag over
    // a potential valid target
    // highlight the target in red
    if ("string" == typeof id) {
        el = YAHOO.util.DDM.getElement(id);
    } else {
        el = YAHOO.util.DDM.getBestMatch(id).getEl();
    }

    el.style.border = "1px solid green";
};

DDSend.prototype.onDragOut = function(e, id) {
    var el;

    // this is called anytime we drag out of
    // a potential valid target
    // remove the highlight
    if ("string" == typeof id) {
        el = YAHOO.util.DDM.getElement(id);
    } else {
        el = YAHOO.util.DDM.getBestMatch(id).getEl();
    }

    el.style.border = "";
}

DDSend.prototype.endDrag = function(e) {
   // override so source object doesn't move when we are done
}
