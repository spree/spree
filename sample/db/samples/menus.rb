main_menu = Spree::Menu.where(
  name: 'Main Menu',
  unique_code: 'spree-all-main'
).first_or_create!

main_menu.store_ids = Spree::Store.ids
main_menu.save!

footer_menu = Spree::Menu.where(
  name: 'Footer Menu',
  unique_code: 'spree-all-footer'
).first_or_create!

footer_menu.store_ids = Spree::Store.ids
footer_menu.save!
