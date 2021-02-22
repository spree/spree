var root = typeof exports !== 'undefined' && exports !== null ? exports : this

root.taxon_tree_menu = function (obj, context) {
  var adminBaseUrl = Spree.url(Spree.routes.admin_taxonomy_taxons_path)
  var editUrl = adminBaseUrl.clone()
  editUrl.setPath(editUrl.path() + '/' + obj.attr('id') + '/edit')
  return {
    create: {
      label: '<i class="icon icon-add"></i>' + Spree.translations.add,
      action: function (obj) {
        return context.create(obj)
      }
    },
    rename: {
      label: '<i class="icon icon-edit"></i> ' + Spree.translations.rename,
      action: function (obj) {
        return context.rename(obj)
      }
    },
    remove: {
      label: '<i class="icon icon-delete"></i> ' + Spree.translations.remove,
      action: function (obj) {
        return context.remove(obj)
      }
    },
    edit: {
      separator_before: true,
      label: '<i class="icon icon-settings"></i> ' + Spree.translations.edit,
      action: function () {
        window.location = editUrl.toString()
        return window.location
      }
    }
  }
}
