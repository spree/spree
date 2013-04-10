var handle_ajax_error = function(XMLHttpRequest, textStatus, errorThrown){
  $.jstree.rollback(last_rollback);
  $("#ajax_error").show().html("<strong>" + server_error + "</strong><br />" + taxonomy_tree_error);
};

//var handle_move = function(li, target, droppped, tree, rb) {
var handle_move = function(e, data) {
  last_rollback = data.rlbk;
  var position = data.rslt.cp;
  var node = data.rslt.o;
  var new_parent = data.rslt.np;

  url.setPath(url.path() + '/' + node.attr("id"));
  $.ajax({
    type: "POST",
    dataType: "json",
    url: url.toString(),
    data: ({_method: "put", "taxon[parent_id]": new_parent.attr("id"), "taxon[position]": position }),
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

  $.ajax({
    type: "POST",
    dataType: "json",
    url: base_url.toString(),
    data: ({"taxon[name]": name, "taxon[parent_id]": new_parent.attr("id"), "taxon[position]": position }),
    error: handle_ajax_error,
    success: function(data,result) {
      node.attr('id', data.id);
    }
  });

};

var handle_rename = function(e, data) {
  last_rollback = data.rlbk;
  var node = data.rslt.obj;
  var name = data.rslt.new_name;

  url = Spree.url(base_url);
  url.setPath(url.path() + '/' + node.attr("id"));

  $.ajax({
    type: "POST",
    dataType: "json",
    url: url.toString(),
    data: {_method: "put", "taxon[name]": name },
    error: handle_ajax_error
  });
 };

var handle_delete = function(e, data){
  last_rollback = data.rlbk;
  var node = data.rslt.obj;
  delete_url = base_url.clone(); 
  delete_url.setPath(delete_url.path() + '/' + node.attr("id"));
  jConfirm(Spree.translations.are_you_sure_delete, Spree.translations.confirm_delete, function(r) {
    if(r){
      $.ajax({
        type: "POST",
        dataType: "json",
        url: delete_url.toString(),
        data: {_method: "delete"},
        error: handle_ajax_error
      });
    }else{
      $.jstree.rollback(last_rollback);
      last_rollback = null;
    }
  });

};


var setup_taxonomy_tree = function(taxonomy_id) {
  if(taxonomy_id!=undefined){
    $.ajax({
      url: '/api/taxonomies/' + taxonomy_id + '/jstree', 
      success: function(taxonomy) { 

        // this is defined within admin/taxonomies/edit
        base_url = Spree.url(Spree.routes.taxonomy_taxons_path);
        admin_base_url = Spree.url(Spree.routes.admin_taxonomy_taxons_path);

        is_cut = false;
        last_rollback = null;

        var conf = {
          json_data : {
            data: taxonomy, 
            ajax: {
              url: function (e) {
                return '/api/taxonomies/' + taxonomy_id + '/taxons/' + e.attr('id') + '/jstree'
              },
            }
          },
          themes: {
            theme: "apple",
            url: "/assets/jquery.jstree/themes/apple/style.css"
          },
          strings: {
            new_node: new_taxon,
            loading: Spree.translations.loading + "..."
          },
          crrm: {
            move: {
              check_move: function (m) {
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
          contextmenu: {
             items: function(obj) {
                var id_of_node = obj.attr("id");
                var type_of_node = obj.attr("rel");
                var menu = {};
                var edit_url = admin_base_url.clone();
                edit_url.setPath(edit_url.path() + '/' + obj.attr("id") + "/edit");
                if(type_of_node == "root") {
                  menu = {
                    create: {
                      label: "<i class='icon-plus'></i> " + Spree.translations.add,
                      action: function (obj) { this.create(obj); }
                    },
                     paste: {
                       separator_before: true,
                       label: "<i class='icon-paste'></i> " + Spree.translations.paste,
                       action: function (obj) { is_cut = false; this.paste(obj); },
                       _disabled: is_cut == false
                    },
                    edit : {
                      separator_before: true,
                      label: "<i class='icon-edit'></i> " + Spree.translations.edit,
                      action           : function (obj) { window.location = admin_base_url.setPath(admin_base_url.path() + '/' + obj.attr("id") + "/edit/").toString; }
                    }
                  }
                } else {
                  menu =  {
                    create: {
                      label: "<i class='icon-plus'></i> " + Spree.translations.add,
                      action: function (obj) { this.create(obj); }
                    },
                    rename: {
                      label: "<i class='icon-pencil'></i> " + Spree.translations.rename,
                      action: function (obj) { this.rename(obj); }
                    },
                    remove: {
                      label: "<i class='icon-trash'></i> " + Spree.translations.remove,
                      action: function (obj) { this.remove(obj); }
                    },
                    cut: {
                      separator_before : true,
                      label: "<i class='icon-cut'></i> " + Spree.translations.cut,
                      action: function (obj) { is_cut = true; this.cut(obj); }
                    },
                    paste: {
                      label: "<i class='icon-paste'></i> " + Spree.translations.paste,
                      action: function (obj) { is_cut = false; this.paste(obj); },
                      "_disabled": is_cut == false
                    },
                    edit: {
                      separator_before: true,
                      label: "<i class='icon-edit'></i> " + Spree.translations.edit,
                      action: function (obj) { window.location = edit_url.toString() }
                    }
                  }
                }
                return menu;
            }
          },

          plugins: [ "themes", "json_data", "dnd", "crrm", "contextmenu"]
        }

        $("#taxonomy_tree").jstree(conf)
          .bind("move_node.jstree", handle_move)
          .bind("remove.jstree", handle_delete)
          .bind("create.jstree", handle_create)
          .bind("rename.jstree", handle_rename)
          .bind("loaded.jstree", function() {
            $(this).jstree("core").toggle_node($('.jstree-icon').first())
          })
          }
        })

    $("#taxonomy_tree a").on("dblclick", function (e) {
     $("#taxonomy_tree").jstree("rename", this)
    });



    $(document).keypress(function(e){
      //surpress form submit on enter/return
      if (e.keyCode == 13){
          e.preventDefault();
      }
    });
  }
};
