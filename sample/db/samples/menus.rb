main_menu = Spree::Menu.where(
  name: 'Main Menu'
).first_or_create!

main_menu.store_ids = Spree::Store.ids
main_menu.save!

footer_menu = Spree::Menu.where(
  name: 'Footer Menu'
).first_or_create!

footer_menu.store_ids = Spree::Store.ids
footer_menu.save!
