/* globals show_flash, base_url, taxon_tree_menu */

function handleAjaxError (lastRollback) {
  $.jstree.rollback(lastRollback)
  show_flash('error', '<strong>' + Spree.translations.server_error + '</strong><br />' + Spree.translations.taxonomy_tree_error)
}

function handleMove (e, data) {
  var lastRollback = data.rlbk
  var position = data.rslt.cp
  var node = data.rslt.o
  var newParent = data.rslt.np
  var url = Spree.url(base_url).clone()
  url.setPath(url.path() + '/' + node.prop('id'))
  if (newParent.attr('id') === data.rslt.op.attr('id') && position > data.rslt.cop) {
    position = position - 1
  }
  $.ajax({
    type: 'POST',
    dataType: 'json',
    url: url.toString(),
    data: {
      _method: 'put',
      'taxon[parent_id]': newParent.prop('id'),
      'taxon[child_index]': position,
      token: Spree.api_key
    }
  }).fail(function () {
    handleAjaxError(lastRollback)
  })
  return true
}

function handleCreate (e, data) {
  var lastRollback = data.rlbk
  var node = data.rslt.obj
  var name = data.rslt.name
  var position = data.rslt.position
  var newParent = data.rslt.parent
  return $.ajax({
    type: 'POST',
    dataType: 'json',
    url: base_url.toString(),
    data: {
      'taxon[name]': name,
      'taxon[parent_id]': newParent.prop('id'),
      'taxon[child_index]': position,
      token: Spree.api_key
    }
  }).done(function (data) {
    node.prop('id', data.id)
  }).fail(function () {
    return handleAjaxError(lastRollback)
  })
}

function handleRename (e, data) {
  var lastRollback = data.rlbk
  var node = data.rslt.obj
  var name = data.rslt.new_name
  var url = Spree.url(base_url).clone()
  url.setPath(url.path() + '/' + node.prop('id'))
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
    handleAjaxError(lastRollback)
  })
}

function handleDelete (e, data) {
  var lastRollback = data.rlbk
  var node = data.rslt.obj
  var deleteUrl = base_url.clone()
  deleteUrl.setPath(deleteUrl.path() + '/' + node.prop('id'))
  if (confirm(Spree.translations.are_you_sure_delete)) {
    $.ajax({
      type: 'POST',
      dataType: 'json',
      url: deleteUrl.toString(),
      data: {
        _method: 'delete',
        token: Spree.api_key
      }
    }).fail(function () {
      handleAjaxError(lastRollback)
    })
  } else {
    $.jstree.rollback(lastRollback)
    lastRollback = null
  }
}

var root = typeof exports !== 'undefined' && exports !== null ? exports : this

root.setup_taxonomy_tree = function (taxonomyId) {
  var $taxonomyTree = $('#taxonomy_tree')
  if (taxonomyId !== void 0) {
    // this is defined within admin/taxonomies/edit
    root.base_url = Spree.url(Spree.routes.taxonomy_taxons_path)
    $.ajax({
      url: Spree.url(base_url.path().replace('/taxons', '/jstree')).toString(),
      data: {
        token: Spree.api_key
      }
    }).done(function (taxonomy) {
      // eslint-disable-next-line no-unused-vars
      var lastRollback = null
      var conf = {
        json_data: {
          data: taxonomy,
          ajax: {
            url: function (e) {
              return Spree.url(base_url.path() + '/' + e.prop('id') + '/jstree' + '?token=' + Spree.api_key).toString()
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
              var newParent, node, position
              position = m.cp
              node = m.o
              newParent = m.np
              if (!newParent || node.prop('rel') === 'root') {
                return false
              }
              // can't drop before root
              if (newParent.prop('id') === 'taxonomy_tree' && position === 0) {
                return false
              }
              return true
            }
          }
        },
        contextmenu: {
          items: function (obj) {
            return taxon_tree_menu(obj, this)
          }
        },
        plugins: ['themes', 'json_data', 'dnd', 'crrm', 'contextmenu']
      }
      return $taxonomyTree.jstree(conf).bind('move_node.jstree', handleMove).bind('remove.jstree', handleDelete).bind('create.jstree', handleCreate).bind('rename.jstree', handleRename).bind('loaded.jstree', function () {
        return $(this).jstree('core').toggle_node($('.jstree-icon').first())
      })
    })
    $taxonomyTree.on('dblclick', 'a', function () {
      $taxonomyTree.jstree('rename', this)
    })
    // suppress form submit on enter/return
    $(document).keypress(function (event) {
      if (event.keyCode === 13) {
        event.preventDefault()
      }
    })
  }
}
