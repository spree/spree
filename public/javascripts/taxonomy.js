var base_url = "/admin/taxonomies/" + taxonomy_id + "/taxons/";

var handle_move = function(li, target, droppped) {
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
    data: ({_method: "put", "taxon[parent_id]": parent.id, "taxon[position]": position, authenticity_token: AUTH_TOKEN})        
  });
        
  return true
};

var handle_dblclick = function(li, tree) {
  tree.rename();
};

var handle_rename = function(li) {
  var name = $(li).children()[0].text;
  
  $.ajax({
    type: "POST",
    url: base_url + li.id,
    data: ({_method: "put", "taxon[name]": name, authenticity_token: AUTH_TOKEN})        
  });
};

conf = { 
  ui : {
    theme_path  : "/jsTree/source/themes/",
    context     : [ 
        {
            id      : "create",
            label   : "Create", 
            icon    : "create.png",
            visible : function (NODE, TREE_OBJ) { if(NODE.length != 1) return false; return TREE_OBJ.check("creatable", NODE); }, 
            action  : function (NODE, TREE_OBJ) { TREE_OBJ.create(false, TREE_OBJ.get_node(NODE)); } 
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
         new_node    : "<%= t('new_taxon') %>",
         loading     : "<%= t('loading') %> ..."
  },
  rules : {
    droppable : [ "tree-drop" ],
    multiple : true,
    deletable : "all",
    draggable : "all"
  },
  callback : {
    onmove: handle_move,
    ondblclk: handle_dblclick,
    onrename: handle_rename
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