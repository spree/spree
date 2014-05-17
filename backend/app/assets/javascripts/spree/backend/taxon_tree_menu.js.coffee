root = exports ? this

root.taxon_tree_menu = (obj, context) ->

  base_url = Spree.url(Spree.routes.taxonomy_taxons_path)
  admin_base_url = Spree.url(Spree.routes.admin_taxonomy_taxons_path)
  edit_url = admin_base_url.clone()
  edit_url.setPath(edit_url.path() + '/' + obj.attr("id") + "/edit");

  create:
    label: "<i class='fa fa-plus'></i> " + Spree.translations.add,
    action: (obj) -> context.create(obj)
  rename:
    label: "<i class='fa fa-pencil'></i> " + Spree.translations.rename,
    action: (obj) -> context.rename(obj)
  remove:
    label: "<i class='fa fa-trash'></i> " + Spree.translations.remove,
    action: (obj) -> context.remove(obj)
  edit:
    separator_before: true,
    label: "<i class='fa fa-edit'></i> " + Spree.translations.edit,
    action: (obj) -> window.location = edit_url.toString()
