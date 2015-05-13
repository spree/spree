root = exports ? this

root.taxon_tree_menu = (obj, context) ->

  base_url = Spree.url(Spree.routes.taxonomy_taxons_path)
  admin_base_url = Spree.url(Spree.routes.admin_taxonomy_taxons_path)
  edit_url = admin_base_url.clone()
  edit_url.setPath(edit_url.path() + '/' + obj.attr("id") + "/edit");

  create:
    label: "<span class='icon icon-plus'></span> " + Spree.translations.add,
    action: (obj) -> context.create(obj)
  rename:
    label: "<span class='icon icon-pencil'></span> " + Spree.translations.rename,
    action: (obj) -> context.rename(obj)
  remove:
    label: "<span class='icon icon-trash'></span> " + Spree.translations.remove,
    action: (obj) -> context.remove(obj)
  edit:
    separator_before: true,
    label: "<span class='icon icon-cog'></span> " + Spree.translations.edit,
    action: (obj) -> window.location = edit_url.toString()
