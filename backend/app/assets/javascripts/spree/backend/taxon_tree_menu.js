var root = typeof exports !== 'undefined' && exports !== null ? exports : this

root.taxon_tree_menu = function (obj, context) {
  var adminBaseUrl = Spree.url(Spree.routes.admin_taxonomy_taxons_path)
  var editUrl = adminBaseUrl.clone()
  editUrl.setPath(editUrl.path() + '/' + obj.attr('id') + '/edit')
  return {
    create: {
      label: '<span class="icon icon-plus"></span> ' + Spree.translations.add,
      action: function (obj) {
        return context.create(obj)
      }
    },
    rename: {
      label: '<span class="icon icon-pencil"></span> ' + Spree.translations.rename,
      action: function (obj) {
        return context.rename(obj)
      }
    },
    remove: {
      label: '<span class="icon icon-trash"></span> ' + Spree.translations.remove,
      action: function (obj) {
        return context.remove(obj)
      }
    },
    edit: {
      separator_before: true,
      label: '<span class="icon icon-cog"></span> ' + Spree.translations.edit,
      action: function () {
        window.location = editUrl.toString()
        return window.location
      }
    }
  }
}
