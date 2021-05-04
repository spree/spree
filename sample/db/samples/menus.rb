Spree::Store.ids.each do |store|
  Spree::Menu.where(
    name: 'Main Menu',
    unique_code: 'spree-all-main',
    store_id: store
  ).first_or_create!

  Spree::Menu.where(
    name: 'Footer Menu',
    unique_code: 'spree-all-footer',
    store_id: store
  ).first_or_create!
end
