menus = [
  { name: 'Main Menu' },
  { name: 'Footer' }
]

menus.each do |menu_attrs|
  Spree::Menu.where(menu_attrs).first_or_create!
end
