handle_ajax_error = (XMLHttpRequest, textStatus, errorThrown) ->
  $.jstree.rollback(last_rollback)
  $("#ajax_error").show().html("<strong>" + server_error + "</strong><br />" + taxonomy_tree_error)

handle_move = (e, data) ->
  last_rollback = data.rlbk
  position = data.rslt.cp
  node = data.rslt.o
  new_parent = data.rslt.np

  url = Spree.url(base_url).clone()
  url.setPath url.path() + '/' + node.prop("id")
  $.ajax
    type: "POST",
    dataType: "json",
    url: url.toString(),
    data: {
      _method: "put",
      "taxon[parent_id]": new_parent.prop("id"),
      "taxon[child_index]": position,
      token: Spree.api_key
    },
    error: handle_ajax_error

  true

handle_create = (e, data) ->
  last_rollback = data.rlbk
  node = data.rslt.obj
  name = data.rslt.name
  position = data.rslt.position
  new_parent = data.rslt.parent

  $.ajax
    type: "POST",
    dataType: "json",
    url: base_url.toString(),
    data: {
      "taxon[name]": name,
      "taxon[parent_id]": new_parent.prop("id"),
      "taxon[child_index]": position,
      token: Spree.api_key
    },
    error: handle_ajax_error,
    success: (data,result) ->
      node.prop('id', data.id)

handle_rename = (e, data) ->
  last_rollback = data.rlbk
  node = data.rslt.obj
  name = data.rslt.new_name

  url = Spree.url(base_url).clone()
  url.setPath(url.path() + '/' + node.prop("id"))

  $.ajax
    type: "POST",
    dataType: "json",
    url: url.toString(),
    data: {
      _method: "put",
      "taxon[name]": name,
      token: Spree.api_key
    },
    error: handle_ajax_error

handle_delete = (e, data) ->
  last_rollback = data.rlbk
  node = data.rslt.obj
  delete_url = base_url.clone()
  delete_url.setPath delete_url.path() + '/' + node.prop("id")
  response = confirm(Spree.translations.are_you_sure_delete)
  if response
    $.ajax
      type: "POST",
      dataType: "json",
      url: delete_url.toString(),
      data: {
        _method: "delete",
        token: Spree.api_key
      },
      error: handle_ajax_error
  else
    $.jstree.rollback(last_rollback)
    last_rollback = null

root = exports ? this
root.setup_taxonomy_tree = (taxonomy_id) ->
  $taxonomy_tree = $("#taxonomy_tree")

  if taxonomy_id != undefined
    # this is defined within admin/taxonomies/edit
    root.base_url = Spree.url(Spree.routes.taxonomy_taxons_path)

    $.ajax
      url: Spree.url(base_url.path().replace("/taxons", "/jstree")).toString(),
      data:
        token: Spree.api_key
      success: (taxonomy) ->
        last_rollback = null

        conf =
          json_data:
            data: taxonomy,
            ajax:
              url: (e) ->
                Spree.url(base_url.path() + '/' + e.prop('id') + '/jstree' + '?token=' + Spree.api_key).toString()
          themes:
            theme: "spree",
            url: Spree.url(Spree.routes.jstree_theme_path)
          strings:
            new_node: new_taxon,
            loading: Spree.translations.loading + "..."
          crrm:
            move:
              check_move: (m) ->
                position = m.cp
                node = m.o
                new_parent = m.np

                # no parent or cant drag and drop
                if !new_parent || node.prop("rel") == "root"
                  return false

                # can't drop before root
                if new_parent.prop("id") == "taxonomy_tree" && position == 0
                  return false

                true
          contextmenu:
            items: (obj) ->
              taxon_tree_menu(obj, this)
          plugins: ["themes", "json_data", "dnd", "crrm", "contextmenu"]

        $taxonomy_tree.jstree(conf)
          .bind("move_node.jstree", handle_move)
          .bind("remove.jstree", handle_delete)
          .bind("create.jstree", handle_create)
          .bind("rename.jstree", handle_rename)
          .bind "loaded.jstree", ->
            $(this).jstree("core").toggle_node($('.jstree-icon').first())

    $taxonomy_tree.on "dblclick", "a", (e) ->
      $taxonomy_tree.jstree("rename", this)

    # surpress form submit on enter/return
    $(document).keypress (e) ->
      if e.keyCode == 13
        e.preventDefault()
