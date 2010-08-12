var base_url = "/admin/taxonomies/" + taxonomy_id + "/taxons/";
var child_url = "/admin/taxonomies/" + taxonomy_id + "/get_children.json"
var creating = false;
var delete_confirmed = false;
var last_rollback = null;

var handle_ajax_error = function(XMLHttpRequest, textStatus, errorThrown){
  jQuery.tree.rollback(last_rollback);

  jQuery("#ajax_error").show().html("<strong>" + server_error + "</strong><br/>" + taxonomy_tree_error);
};

var handle_move = function(li, target, droppped, tree, rb) {
  last_rollback = rb;
  var position = jQuery(li).prevAll().length;

  var parent = -1;

  if(droppped=='inside'){
    parent = target;
  }else if(droppped=='after'){
    parent = jQuery(target).parents()[1];
  }else if(droppped=='before'){
    parent = jQuery(target).parents()[1];
  }

  jQuery.ajax({
    type: "POST",
    url: base_url + li.id + ".json",
    data: ({_method: "put", "taxon[parent_id]": parent.id, "taxon[position]": position, authenticity_token: AUTH_TOKEN}),
    error: handle_ajax_error
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
  jQuery.tree.reference('taxonomy_tree').selected.attr('id', id);
}

var handle_rename = function(li, tree, rb) {
  var name = jQuery(li).children(":first").text();
  name = jQuery.trim(name);

  if (creating){
    //actually creating new
    var position = jQuery(li).prevAll().length;
    var parent = jQuery(li).parents()[1];

    jQuery.ajax({
      type: "POST",
      url: base_url,
      data: ({"taxon[name]": name, "taxon[parent_id]": parent.id, "taxon[position]": position, authenticity_token: AUTH_TOKEN}),
      error: handle_ajax_error,
      success: handle_created
    });

    creating = false;
  }else{
    //just renaming
    last_rollback = rb;

    jQuery.ajax({
      type: "POST",
      url: base_url + li.id + ".json",
      data: ({_method: "put", "taxon[name]": name, authenticity_token: AUTH_TOKEN}),
      error: handle_ajax_error
    });
  }
};

var handle_before_delete = function(li){
  if (!delete_confirmed){
    jConfirm('Are you sure you want to delete this taxon?', 'Confirm Taxon Deletion', function(r) {
      if(r){
        delete_confirmed = true;
        jQuery.tree.reference('taxonomy_tree').remove(li);
      }
    });
  }

  return delete_confirmed;
};

var handle_delete = function(li, tree, rb){
  last_rollback = rb;

  jQuery.ajax({
    type: "POST",
    url: base_url + li.id,
    data: ({_method: "delete", authenticity_token: AUTH_TOKEN}),
    error: handle_ajax_error
  });

  delete_confirmed = false;
};

jQuery(document).ready(function(){
  conf = {
    data : {
      type : "json",
      async : true,
      opts : {
        method : "GET",
        url : child_url
      }
    },
    ui : {
      theme_name : "apple"
    },
    lang : {
        new_node    : new_taxon,
        loading     : loading + "..."
      },
    plugins : {
      contextmenu : {
        items : {
          // get rid of the remove item
          remove :{
            visible : function (NODE, TREE_OBJ) { if(jQuery(NODE[0]).attr('rel')=="root") return false; return TREE_OBJ.check("renameable", NODE); },
          },
          rename :{
            visible : function (NODE, TREE_OBJ) { if(jQuery(NODE[0]).attr('rel')=="root") return false; return TREE_OBJ.check("renameable", NODE); },
          },
          cut :{
              id      : "cut",
              label   : "Cut",
              visible : function (NODE, TREE_OBJ) { if(NODE.length != 1 || NODE[0].id == 'root') return false; return true; },
              action  : function (NODE, TREE_OBJ) { TREE_OBJ.cut(NODE); jQuery(NODE).hide(); },
              separator_before : true
          },
          paste :{
              id      : "paste",
              label   : "Paste",
              visible : function (NODE, TREE_OBJ) { if(NODE.length != 1 || NODE[0].id == 'root') return false; return true; },
              action  : function (NODE, TREE_OBJ) { TREE_OBJ.open_branch(NODE); TREE_OBJ.paste(NODE, "inside"); jQuery(NODE).find("li").show(); }
          },
          edit :{
              id      : "edit",
              label   : "Edit",
              visible : function (NODE, TREE_OBJ) { if(NODE.length != 1 || NODE[0].id == 'root') return false; return TREE_OBJ.check("renameable", NODE); },
              action  : function (NODE, TREE_OBJ) { jQuery.each(NODE, function () { window.location = base_url + this.id + "/edit/"; }); }
          }

        }
      }
    },
    rules : {
      // only nodes of type root can be top level nodes
      valid_children : [ "root" ]
    },
    types : {
      // all node types inherit the "default" node type
      "taxon" : {},
      "root" : {
        deletable : false,
        renameable : false,
        draggable : false,
        valid_children : [ "taxon" ]
      }
    },
    callback : {
      onmove: handle_move,
      ondblclk: handle_dblclick,
      onrename: handle_rename,
      oncreate: handle_create,
      beforedelete: handle_before_delete,
      ondelete: handle_delete,
      beforedata: function (n, t) {
        if(n == false) t.settings.data.opts.static = initial;
        else t.settings.data.opts.static = false;

        return { parent_id : $(n).attr("id") || 0 };
        }

    }
  }

  jQuery("#taxonomy_tree").tree(conf);

  jQuery(document).keypress(function(e){
    //surpress form submit on enter/return
    if (e.keyCode == 13){
        e.preventDefault();
    }
  });
});
