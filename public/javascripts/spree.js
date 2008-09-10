/**
This is a collection of javascript functions and whatnot
under the spree namespace that do stuff we find helpful.
Hopefully, this will evolve into a propper class.
**/

var spree;
if (!spree) spree = {};
spree.Class = {};

spree.tree = {};

spree.tree.reset = function() {
	spree.tree.current_draggable = null;
	spree.tree.current_node = null;
	spree.tree.current_root = null;
}

spree.tree.move = function(spree_id) {
 	if (spree.tree.current_node) { 
		spree.tree.cancel_move(spree.tree.current_node.spree_id);
	}

	var node = spree.tree.get_node_by_spree_id(spree_id);
	var node_handle = spree.tree.get_node_handle_by_spree_id(spree_id);

	spree.tree.unregister_expandable_node(node_handle);

	spree.tree.set_current_node(spree_id);
	node_handle.addClassName('draggable');

	spree.tree.hide_children_by_class(node, 'tree-node-options')
	$('tree-node-move-options-' + spree_id).show();
	spree.tree.current_draggable = new Draggable(node, { revert:true });

	spree.tree.set_droppables(spree_id);

	node.parent_handle = node.up('li').down('.tree-drop-node');
}

spree.tree.cancel_move = function(spree_id) {
	node = spree.tree.get_node_by_spree_id(spree_id);
	node_handle = spree.tree.get_node_handle_by_spree_id(spree_id);

	spree.tree.move_droppable(node, node.parent_handle);
	node.parent_node = null;

	spree.tree.end_move(spree_id);
}

spree.tree.save_move = function(spree_id) {
	node = spree.tree.get_node_by_spree_id(spree_id);
	node_handle = spree.tree.get_node_handle_by_spree_id(spree_id);

	parent_id = node.up('li').spree_id;
	// do something to the server here	
	var url = '/admin/taxonomies/move_taxon?id=' + spree_id + '&parent_id=' + parent_id;
	new Ajax.Request(url, { method: 'post',
							onSuccess: spree.tree.ajax_success,
							onFailure: spree.tree.ajax_failure });
	spree.tree.end_move(spree_id);
}

spree.tree.end_move = function(spree_id) {
	node = spree.tree.get_node_by_spree_id(spree_id);
	node_handle = spree.tree.get_node_handle_by_spree_id(spree_id);

	node_handle.removeClassName('draggable');

	$('tree-node-move-options-' + spree_id).hide();
	spree.tree.show_children_by_class(node, 'tree-node-options')
	spree.tree.current_draggable.destroy();
	spree.tree.current_node = null;

	spree.tree.unset_droppables(spree_id);
	spree.tree.register_expandable_nodes();
}

spree.tree.set_droppables = function(spree_id) {
	root_node = spree.tree.find_root_by_spree_id(spree_id);
	node_handle = spree.tree.get_node_handle_by_spree_id(spree_id);

	root_node.descendants().each(function(node, index) {
		if (node.hasClassName('tree-drop-node') &&
			node != node_handle) {
			Droppables.add(node, {hoverclass: 'drop-hover', 
                                  onDrop: spree.tree.move_droppable});
 		}
	});
}

spree.tree.unset_droppables = function(spree_id) {
	root_node = spree.tree.find_root_by_spree_id(spree_id);
	root_node.descendants().each(function(node, index) {
		if (node.hasClassName('tree-drop-node')) {
			Droppables.remove(node);
 		}
	});
}

spree.tree.move_droppable = function(draggable, droparea){
	var new_parent = droparea.up('li').down('ul');
	var orig_parent = draggable.parentNode;
	orig_parent.removeChild(draggable);
	new_parent.appendChild(draggable);

	// It is possible that we added a node to a leaf
	if (droparea.hasClassName('tree-nav-leaf')) {
		droparea.removeClassName('tree-nav-leaf');
		droparea.addClassName('tree-nav-open');
    }

	// It is possible that we have removed the last
	// child from the original parent node
	if (!orig_parent.down('li')) {
		var disp_elem = orig_parent.up('li').down('.tree-drop-node');
		disp_elem.addClassName('tree-nav-leaf');
		disp_elem.removeClassName('tree-nav-open');
		disp_elem.removeClassName('tree-nav-closed');
	}	
	spree.tree.register_expandable_nodes();
}

spree.tree.find_root_by_spree_id = function(spree_id) {
	return spree.tree.get_node_by_spree_id(spree_id).up('.tree')
}

spree.tree.hide_children_by_class = function(node, class)  {
	if (node.className == class) { node.hide(); } 	
	for (var child = node.firstChild; child != null; child = child.nextSibling) {
		spree.tree.hide_children_by_class(child, class)
	}	
}

spree.tree.show_children_by_class = function(node, class)  {
	if (node.className == class) { node.show(); } 	
	for (var child = node.firstChild; child != null; child = child.nextSibling) {
		spree.tree.show_children_by_class(child, class)
	}	
}

spree.tree.set_current_node = function(spree_id) {
	spree.tree.current_node = spree.tree.get_node_by_spree_id(spree_id);
	spree.tree.current_node.spree_id = spree_id	
}

/************************************
 * Get functions
 ************************************/

spree.tree.get_node_by_spree_id = function(spree_id) {
	return $('tree-node-' + spree_id);
}

spree.tree.get_node_handle_by_spree_id = function(spree_id) {
	return $('tree-node-name-' + spree_id)	;
}

spree.tree.get_node_branch_by_spree_id = function(spree_id) {
	return $('tree-branch-' + spree_id);
}

spree.tree.toggle_branch_by_node_handle = function(node_handle) {
	node_handle.next('ul').toggle();
	node_handle.toggleClassName('tree-nav-open');
    node_handle.toggleClassName('tree-nav-closed');
}

spree.tree.toggle_branch_by_event = function(e) {
	node = Event.element(e);
	return spree.tree.toggle_branch_by_node_handle(node);
}

spree.tree.register_expandable_nodes = function() {
	spree.tree.current_root.descendants().each(function(node, index) {
		if ( !node.hasClassName('draggable') ) {
			if ( (node.hasClassName('tree-nav-open') ||
		          node.hasClassName('tree-nav-closed')) &&
	 			  !node.click_event  ) {
				node.click_event = spree.tree.toggle_branch_by_event.bindAsEventListener()
				node.observe('click', node.click_event );
 			}
			else if (node.hasClassName('tree-nav-leaf') && node.click_event) {
				spree.tree.unregister_expandable_node(node);
        	}
		}
	});
}

spree.tree.register_nodes = function() {
	spree.tree.current_root.descendants().each(function(node, index) {
		if (node.hasClassName('tree-node')) {
			node.spree_id = node.identify().match(/^tree-node-(\d+)$/)[1];
		}
		else if (node.hasClassName('tree-drop-node')) {
			node.spree_id = node.identify().match(/^tree-node-name-(\d+)$/)[1];
		}

	});
}

spree.tree.unregister_expandable_node = function(node) {
	node.stopObserving('click', node.click_event);
	node.click_event = null;
}

spree.tree.ajax_failure = function(transport) {
	alert("Fail!");
}

spree.tree.ajax_success = function(transport) {
	alert("Win!");
}

spree.tree.set_current_root = function() {
	spree.tree.current_root = $('spree-tree');
}

spree.tree.tree_onload = function() {
	spree.tree.reset();
	spree.tree.set_current_root();
	spree.tree.register_nodes();
	spree.tree.register_expandable_nodes();
}

/*******************************************************************/
/* Spree Taxon Product Management                                  */
/*******************************************************************/

spree.taxon = {}
spree.taxon.pm = {}
spree.taxon.current_taxon = null;

spree.taxon.pm.register_all = function() {
	$$('.product-action').each(function(node, index) {
		node.product_id = node.identify().match(/^product-(\d+)$/)[1];
	});

	$$('.product-action-add').each(function(node, index) {
		spree.register_node_click_event(node, spree.taxon.pm.add_product_event);
	});
	$$('.product-action-remove').each(function(node, index) {
		spree.register_node_click_event(node, spree.taxon.pm.remove_product_event);
	});
}

spree.taxon.pm.add_product = function(node) {
	to_move = node.up('li');
	to_move.parentNode.removeChild(to_move);
	$('add-product-target').appendChild(to_move);

	node.removeClassName('product-action-add');
	node.addClassName('product-action-remove');
	node.toggleClassName('product-modified');
	spree.unregister_node_click_event(node);
	spree.register_node_click_event(node, spree.taxon.pm.remove_product_event);
	
}

spree.taxon.pm.remove_product = function(node) {
	to_move = node.up('li');
	to_move.parentNode.removeChild(to_move);
	$('remove-product-target').appendChild(to_move);

	node.removeClassName('product-action-remove');
	node.addClassName('product-action-add');
	node.toggleClassName('product-modified');
	spree.unregister_node_click_event(node);
	spree.register_node_click_event(node, spree.taxon.pm.add_product_event);
}

spree.taxon.pm.add_product_event = function(e) {
	spree.taxon.pm.add_product(Event.element(e));
}

spree.taxon.pm.remove_product_event = function(e) {
	spree.taxon.pm.remove_product(Event.element(e));
}

spree.taxon.pm.save_products = function(container, taxon_id) {
	product_ids = [];
	$('add-product-target').descendants().each(function(node, index) {
		if (node.hasClassName('product-action')) {
			product_ids[product_ids.length] = node.product_id;
		}		
	});

	var url = '/admin/taxonomies/assign_products?id=' + taxon_id + 
	          '&product_ids[]=' + product_ids.join("&product_ids[]=");
	new Ajax.Updater(container, url, { method: 'post',
                                       asynchronous:true,
                                       evalScripts:true });
}


spree.unregister_node_click_event = function(node) {
	node.stopObserving('click', node.click_event);
	node.click_event = null;
}

spree.register_node_click_event = function(node, func) {
	node.click_event = func.bindAsEventListener();
	node.observe('click', node.click_event);
}


spree.taxon.pm.onload = function(taxon_id) {
	spree.taxon.current_taxon = taxon_id;
	spree.taxon.pm.register_all();	
}

window.onload = function() {
	spree.tree.reset();
}