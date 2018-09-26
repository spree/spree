function handle_ajax_error(last_rollback) {
  $.jstree.rollback(last_rollback);
  show_flash('error', '<strong>' + Spree.translations.server_error + '</strong><br />' + Spree.translations.taxonomy_tree_error);
}

function handle_move(e, data) {
  var last_rollback = data.rlbk;
  var position = data.rslt.cp;
  var node = data.rslt.o;
  var new_parent = data.rslt.np;
  var url = Spree.url(base_url).clone();
  url.setPath(url.path() + '/' + node.prop('id'));
  $.ajax({
    type: 'POST',
    dataType: 'json',
    url: url.toString(),
    data: {
      _method: 'put',
      'taxon[parent_id]': new_parent.prop('id'),
      'taxon[child_index]': position,
      token: Spree.api_key
    },
  }).fail(function () {
    handle_ajax_error(last_rollback);
  });
  return true;
}

function handle_create(e, data) {
  var last_rollback = data.rlbk;
  var node = data.rslt.obj;
  var name = data.rslt.name;
  var position = data.rslt.position;
  var new_parent = data.rslt.parent;
  return $.ajax({
    type: 'POST',
    dataType: 'json',
    url: base_url.toString(),
    data: {
      'taxon[name]': name,
      'taxon[parent_id]': new_parent.prop('id'),
      'taxon[child_index]': position,
      token: Spree.api_key
    }
  }).done(function (data) {
    node.prop('id', data.id);
  }).fail(function () {
    return handle_ajax_error(last_rollback);
  });
}

function handle_rename(e, data) {
  var last_rollback = data.rlbk;
  var node = data.rslt.obj;
  var name = data.rslt.new_name;
  var url = Spree.url(base_url).clone();
  url.setPath(url.path() + '/' + node.prop('id'));
  return $.ajax({
    type: 'POST',
    dataType: 'json',
    url: url.toString(),
    data: {
      _method: 'put',
      'taxon[name]': name,
      token: Spree.api_key
    }
  }).fail(function () {
    handle_ajax_error(last_rollback);
  });
}

function handle_delete(e, data) {
  var last_rollback = data.rlbk;
  var node = data.rslt.obj;
  var delete_url = base_url.clone();
  delete_url.setPath(delete_url.path() + '/' + node.prop('id'));
  if (confirm(Spree.translations.are_you_sure_delete)) {
    $.ajax({
      type: 'POST',
      dataType: 'json',
      url: delete_url.toString(),
      data: {
        _method: 'delete',
        token: Spree.api_key
      }
    }).fail(function () {
      handle_ajax_error(last_rollback);
    });
  } else {
    $.jstree.rollback(last_rollback);
    last_rollback = null;
  }
}

var root = typeof exports !== 'undefined' && exports !== null ? exports : this;

root.setup_taxonomy_tree = function (taxonomy_id) {
  var $taxonomy_tree = $('#taxonomy_tree');
  if (taxonomy_id !== void 0) {
    // this is defined within admin/taxonomies/edit
    root.base_url = Spree.url(Spree.routes.taxonomy_taxons_path);
    $.ajax({
      url: Spree.url(base_url.path().replace('/taxons', '/jstree')).toString(),
      data: {
        token: Spree.api_key
      }
    }).done(function (taxonomy) {
      var last_rollback = null;
      var conf = {
        json_data: {
          data: taxonomy,
          ajax: {
            url: function (e) {
              return Spree.url(base_url.path() + '/' + e.prop('id') + '/jstree' + '?token=' + Spree.api_key).toString();
            }
          }
        },
        themes: {
          theme: 'spree',
          url: Spree.url(Spree.routes.jstree_theme_path)
        },
        strings: {
          new_node: Spree.translations.new_taxon,
          loading: Spree.translations.loading + '...'
        },
        crrm: {
          move: {
            check_move: function (m) {
              var new_parent, node, position;
              position = m.cp;
              node = m.o;
              new_parent = m.np;
              if (!new_parent || node.prop('rel') === 'root') {
                return false;
              }
              // can't drop before root
              if (new_parent.prop('id') === 'taxonomy_tree' && position === 0) {
                return false;
              }
              return true;
            }
          }
        },
        contextmenu: {
          items: function (obj) {
            return taxon_tree_menu(obj, this);
          }
        },
        plugins: ['themes', 'json_data', 'dnd', 'crrm', 'contextmenu']
      };
      return $taxonomy_tree.jstree(conf).bind('move_node.jstree', handle_move).bind('remove.jstree', handle_delete).bind('create.jstree', handle_create).bind('rename.jstree', handle_rename).bind('loaded.jstree', function () {
        return $(this).jstree('core').toggle_node($('.jstree-icon').first());
      });
    });
    $taxonomy_tree.on('dblclick', 'a', function () {
      $taxonomy_tree.jstree('rename', this);
    });
    // surpress form submit on enter/return
    $(document).keypress(function (event) {
      if (event.keyCode === 13) {
        event.preventDefault();
      }
    });
  }
};
