var base_url = "/admin/taxonomies/" + taxonomy_id + "/taxons/";
var child_url = "/admin/taxonomies/" + taxonomy_id + "/get_children.json"
var is_cut = false;
var last_rollback = null;

var handle_ajax_error = function(XMLHttpRequest, textStatus, errorThrown){
  jQuery.jstree.rollback(last_rollback);
  jQuery("#ajax_error").show().html("<strong>" + server_error + "</strong><br/>" + taxonomy_tree_error);
};

//var handle_move = function(li, target, droppped, tree, rb) {
var handle_move = function(e, data) {
  last_rollback = data.rlbk;
  var position = data.rslt.cp;
  var node = data.rslt.o;
  var new_parent = data.rslt.np;

  jQuery.ajax({
    type: "POST",
    url: base_url + node.attr("id") + ".json",
    data: ({_method: "put", "taxon[parent_id]": new_parent.attr("id"), "taxon[position]": position, authenticity_token: AUTH_TOKEN}),
    error: handle_ajax_error
  });

  return true
};

var handle_create = function(e, data) {
  last_rollback = data.rlbk;
  var node = data.rslt.obj;
  var name = data.rslt.name;
  var position = data.rslt.position;
  var new_parent = data.rslt.parent;

  jQuery.ajax({
    type: "POST",
    url: base_url,
    data: ({"taxon[name]": name, "taxon[parent_id]": new_parent.attr("id"), "taxon[position]": position, authenticity_token: AUTH_TOKEN}),
    error: handle_ajax_error,
    success: function(id,result) {
      node.attr('id', id);
    }
  });

};

var handle_rename = function(e, data) {
  last_rollback = data.rlbk;
  var node = data.rslt.obj;
  var name = data.rslt.new_name;

  jQuery.ajax({
    type: "POST",
    url: base_url + node.attr("id") + ".json",
    data: ({_method: "put", "taxon[name]": name, authenticity_token: AUTH_TOKEN}),
    error: handle_ajax_error
  });
 };

var handle_delete = function(e, data){
  last_rollback = data.rlbk;
  var node = data.rslt.obj;

  jConfirm('Are you sure you want to delete this taxon?', 'Confirm Taxon Deletion', function(r) {
    if(r){
      jQuery.ajax({
        type: "POST",
        url: base_url + node.attr("id"),
        data: ({_method: "delete", authenticity_token: AUTH_TOKEN}),
        error: handle_ajax_error
      });
    }else{
      jQuery.jstree.rollback(last_rollback);
      last_rollback = null;
    }
  });

};

jQuery(document).ready(function(){
  var conf = {
    json_data : {
      "data" : initial,
      "ajax" : {
        "url" : child_url,
        "data" : function (n) {
          return { parent_id : n.attr ? n.attr("id") : 0 };
        }
      }
    },
    "themes" : {
      "theme" : "apple",
      "url" : "/javascripts/jsTree/themes/apple/style.css"
    },
    "strings" : {
      "new_node" : new_taxon,
      "loading" : loading + "..."
    },
		"crrm" : {
			"move" : {
				"check_move" : function (m) {
          var position = m.cp;
          var node = m.o;
          var new_parent = m.np;

          if(!new_parent) return false; //no parent

          if(node.attr("rel")=="root") return false; //can't drag root

          if(new_parent.attr("id")=="taxonomy_tree" && position==0) return false; // can't drop before root

          return true;

				}
			}
		},
    "contextmenu" : {
       "items" : function(obj) {
          var id_of_node = obj.attr("id");
          var type_of_node = obj.attr("rel");
          var menu = {};
          if(type_of_node == "root") {
            menu = {
              "create" : {
                "label"            : "Create",
                "action"           : function (obj) { this.create(obj); }
              },
               "paste" : {
                 "separator_before" : true,
                 "label"            : "Paste",
                 "action"           : function (obj) { is_cut = false; this.paste(obj); },
                 "_disabled"        : is_cut == false
              },
              "edit" : {
                "separator_before" : true,
                "label"            : "Edit",
                "action"           : function (obj) { window.location = base_url + obj.attr("id") + "/edit/"; }
              }
            }
          } else {
            menu =  {
              "create" : {
                "label"            : "Create",
                "action"           : function (obj) { this.create(obj); }
              },
              "rename" : {
                "label"            : "Rename",
                "action"           : function (obj) { this.rename(obj); }
              },
              "remove" : {
                "label"            : "Remove",
                "action"           : function (obj) { this.remove(obj); }
              },
              "cut" : {
                "separator_before" : true,
                "label"            : "Cut",
                "action"           : function (obj) { is_cut = true; this.cut(obj); }
              },
              "paste" : {
                "label"            : "Paste",
                "action"           : function (obj) { is_cut = false; this.paste(obj); },
                "_disabled"        : is_cut == false
              },
              "edit" : {
                "separator_before" : true,
                "label"            : "Edit",
                "action"           : function (obj) { window.location = base_url + obj.attr("id") + "/edit/"; }
              }
                  }
          }
          return menu;
      }
    },

    "plugins" : [ "themes", "json_data", "dnd", "crrm", "contextmenu"]
  }

  jQuery("#taxonomy_tree").jstree(conf)
    .bind("move_node.jstree", handle_move)
    .bind("remove.jstree", handle_delete)
    .bind("create.jstree", handle_create)
    .bind("rename.jstree", handle_rename);

  jQuery("#taxonomy_tree").delegate("a", "dblclick", function (e) {
   jQuery("#taxonomy_tree").jstree("rename", this)
  });


  jQuery(document).keypress(function(e){
    //surpress form submit on enter/return
    if (e.keyCode == 13){
        e.preventDefault();
    }
  });
});


