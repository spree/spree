root = exports ? this

root.taxon_tree_menu = (obj, context) ->

  edit_url = admin_base_url.clone()
  edit_url.setPath(edit_url.path() + '/' + obj.attr("id") + "/edit");

  create:
    label: "<i class='icon-plus'></i> " + Spree.translations.add,
    action: (obj) -> context.create(obj)
  rename:
    label: "<i class='icon-pencil'></i> " + Spree.translations.rename,
    action: (obj) -> context.rename(obj)
  remove:
    label: "<i class='icon-trash'></i> " + Spree.translations.remove,
    action: (obj) -> context.remove(obj)
  cut:
    separator_before : true,
    label: "<i class='icon-cut'></i> " + Spree.translations.cut,
    action: (obj) -> is_cut = true; context.cut(obj)
  paste:
    label: "<i class='icon-paste'></i> " + Spree.translations.paste,
    action: (obj) -> is_cut = false; context.paste(obj),
    "_disabled": is_cut == false
  edit:
    separator_before: true,
    label: "<i class='icon-edit'></i> " + Spree.translations.edit,
    action: (obj) -> window.location = edit_url.toString()
