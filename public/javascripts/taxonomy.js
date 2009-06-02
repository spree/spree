var base_url = "/admin/taxonomies/" + taxonomy_id + "/taxons/";
var creating = false;
var delete_confirmed = false;
var last_rollback = null;


var show_progress = function(){
	$("#progress").show();
	$("#ajax_error").hide();
}

var hide_progress = function(){
	$("#progress").hide();
}

var handle_ajax_error = function(XMLHttpRequest, textStatus, errorThrown){
	$.tree_rollback(last_rollback);
	$("#progress").hide();
	$("#ajax_error").show().html("<strong>" + server_error + "</strong><br/>" + taxonomy_tree_error);
};

var handle_move = function(li, target, droppped, tree, rb) {
	last_rollback = rb;
  var position = $(li).prevAll().length;

  var parent = -1;
  
  if(droppped=='inside'){
    parent = target;
  }else if(droppped=='after'){
    parent = $(target).parents()[1];
  }else if(droppped=='before'){
    parent = $(target).parents()[1];
  }
 
  $.ajax({
    type: "POST",
    url: base_url + li.id,
    data: ({_method: "put", "taxon[parent_id]": parent.id, "taxon[position]": position, authenticity_token: AUTH_TOKEN}),
		beforeSend: show_progress,
    error: handle_ajax_error,
		success: hide_progress
  });
        
  return true
};

var handle_dblclick = function(li, tree) {
  tree.rename();
};

var handle_create = function(parent, sib, created, tree, rb){
	last_rollback = rb;
	creating=true;	
};

var handle_created = function(id,result) {
	hide_progress();
	
	$.tree_reference('taxonomy_tree').selected.attr('id', id);
}

var handle_rename = function(li, bl, tree, rb) {
  var name = $(li).children()[0].text;
  
	if (creating){
		//actually creating new
		var position = $(li).prevAll().length;
		var parent = $(li).parents()[1];
	  
		$.ajax({
	    type: "POST",
	    url: base_url,
	    data: ({"taxon[name]": name, "taxon[parent_id]": parent.id, "taxon[position]": position, authenticity_token: AUTH_TOKEN}),
	    beforeSend: show_progress,
			error: handle_ajax_error,
	  	success: handle_created
	  });	
	
		creating = false;
	}else{
		//just renaming
		last_rollback = rb;
		
	  $.ajax({
	    type: "POST",
	    url: base_url + li.id,
	    data: ({_method: "put", "taxon[name]": name, authenticity_token: AUTH_TOKEN}),
	    beforeSend: show_progress,
			error: handle_ajax_error,
			success: hide_progress        
	  });
	}
};

var handle_before_delete = function(li){
	$.alerts.dialogClass = "spree";
	
	if (!delete_confirmed){
		jConfirm('Are you sure you want to delete this taxon?', 'Confirm Taxon Deletion', function(r) {
			if(r){
				delete_confirmed = true;
				$.tree_reference('taxonomy_tree').remove(li);
			}
		});
	}
	
	return delete_confirmed;
};

var handle_delete = function(li, tree, rb){
	last_rollback = rb;
		
	$.ajax({
    type: "POST",
    url: base_url + li.id,
    data: ({_method: "delete", authenticity_token: AUTH_TOKEN}),
   	beforeSend: show_progress,
		error: handle_ajax_error,
		success: hide_progress		
  });

	delete_confirmed = false;
};

conf = { 
  ui : {
    theme_path  : "/javascripts/jsTree/source/themes/",
		theme_name	: "spree",
    context     : [ 
        {
            id      : "create",
            label   : "Create", 
            icon    : "create.png",
            visible : function (NODE, TREE_OBJ) { if(NODE.length != 1) return false; return TREE_OBJ.check("creatable", NODE); }, 
            action  : function (NODE, TREE_OBJ) { TREE_OBJ.create({ attributes : { 'rel' : 'taxon' } }, TREE_OBJ.get_node(NODE)); } 
        },
        "separator",
        { 
            id      : "rename",
            label   : "Rename", 
            icon    : "rename.png",
            visible : function (NODE, TREE_OBJ) { if(NODE.length != 1 || NODE[0].id == 'root') return false; return TREE_OBJ.check("renameable", NODE); }, 
            action  : function (NODE, TREE_OBJ) { TREE_OBJ.rename(); } 
        },
        { 
            id      : "delete",
            label   : "Delete",
            icon    : "remove.png",
            visible : function (NODE, TREE_OBJ) { var ok = true; $.each(NODE, function () { if(TREE_OBJ.check("deletable", this) == false || this.id == 'root') ok = false; return false; }); return ok; }, 
            action  : function (NODE, TREE_OBJ) { $.each(NODE, function () { TREE_OBJ.remove(this); }); } 
        },
        "separator",
        { 
            id      : "cut",
            label   : "Cut",
            icon    : "cut.png",
            visible : function (NODE, TREE_OBJ) { if(NODE.length != 1 || NODE[0].id == 'root') return false; return true; }, 
            action  : function (NODE, TREE_OBJ) { TREE_OBJ.cut(); $(NODE).hide(); } 
        },
        { 
            id      : "paste",
            label   : "Paste",
            icon    : "paste.png",
            visible : function (NODE, TREE_OBJ) { if(NODE.length != 1 || NODE[0].id == 'root') return false; return true; }, 
            action  : function (NODE, TREE_OBJ) { TREE_OBJ.open_branch(NODE); TREE_OBJ.paste(NODE); $(NODE).children(":last").children(":last").show(); } 
        }

    ]
  },
  lang : {
         new_node    : new_taxon,
         loading     : loading + "..."
  },
  rules : {
    droppable : [ "tree-drop" ],
    multiple : true,
    deletable : ["taxon"],
    draggable : ["taxon"],
	 	dragrules : [ "taxon * taxon", "taxon inside root", ],
		renameable  : ["taxon"]
  },
  callback : {
    onmove: handle_move,
    ondblclk: handle_dblclick,
    onrename: handle_rename,
		oncreate: handle_create,
		beforedelete: handle_before_delete,
		ondelete: handle_delete
  }
};

$(document).ready(function(){
	
  tax_tree = $.tree_create();
  tax_tree.init($("#taxonomy_tree"), $.extend({},conf));
  
	$(document).keypress(function(e){
    //surpress form submit on enter/return
    if (e.keyCode == 13){
        e.preventDefault();
    } 
  });
});