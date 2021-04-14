main_menu = Spree::Menu.find_by!(name: 'Main Menu')

##############
# Root Items #
##############
main_menu_root_women = Spree::MenuItem.where(
  name: 'Women',
  item_type: 'Link',
  menu_id: main_menu
).first_or_create!

main_menu_root_men = Spree::MenuItem.where(
  name: 'Men',
  item_type: 'Link',
  menu_id: main_menu
).first_or_create!

main_menu_root_sw = Spree::MenuItem.where(
  name: 'Sportsware',
  item_type: 'Link',
  menu_id: main_menu
).first_or_create!

##############
# Catagories #
##############
main_menu_cat_women = Spree::MenuItem.where(
  name: 'Catagories',
  item_type: 'Container',
  menu_id: main_menu,
  parent_id: main_menu_root_women
).first_or_create!

main_menu_cat_men = Spree::MenuItem.where(
  name: 'Catagories',
  item_type: 'Container',
  menu_id: main_menu,
  parent_id: main_menu_root_men
).first_or_create!

main_menu_cat_sw = Spree::MenuItem.where(
  name: 'Catagories',
  item_type: 'Container',
  menu_id: main_menu,
  parent_id: main_menu_root_sw
).first_or_create!

##############
# Promotions #
##############
main_menu_promo_women = Spree::MenuItem.where(
  name: 'Promos',
  item_type: 'Container',
  menu_id: main_menu,
  parent_id: main_menu_root_women
).first_or_create!

main_menu_promo_men = Spree::MenuItem.where(
  name: 'Promos',
  item_type: 'Container',
  menu_id: main_menu,
  parent_id: main_menu_root_men
).first_or_create!

main_menu_promo_sw = Spree::MenuItem.where(
  name: 'Promos',
  item_type: 'Container',
  menu_id: main_menu,
  parent_id: main_menu_root_sw
).first_or_create!

PROMOS = [main_menu_promo_women, main_menu_promo_men, main_menu_promo_sw]
summer = Spree::Taxon.find_by!(permalink: 'new-collection/summer-2021')
offers = Spree::Taxon.find_by!(permalink: 'special-offers/30-percent-off')

#####################
# Links For: PROMOS #
#####################
PROMOS.each do |promo|
  Spree::MenuItem.where(
    name: 'New Collection',
    subtitle: "Summer #{Date.today.year}",
    linked_resource_type: 'Taxon',
    linked_resource_id: summer.id,
    item_type: 'Promotion',
    menu_id: main_menu,
    parent_id: promo
  ).first_or_create!

  Spree::MenuItem.where(
    name: 'Special Offers',
    subtitle: 'Get up to 30% OFF',
    linked_resource_type: 'Taxon',
    linked_resource_id: offers.id,
    item_type: 'Promotion',
    menu_id: main_menu,
    parent_id: promo
  ).first_or_create!
end

#################################
# Links For: WOMEN / CATAGORIES #
#################################
Spree::MenuItem.where(
  name: 'Skirts',
  linked_resource_type: 'URL',
  url: '/t/women/skirts',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_women
).first_or_create!

Spree::MenuItem.where(
  name: 'Dresses',
  linked_resource_type: 'URL',
  url: '/t/women/dresses',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_women
).first_or_create!

Spree::MenuItem.where(
  name: 'Shirts And Blouses',
  linked_resource_type: 'URL',
  url: '/t/women/shirts-and-blouses',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_women
).first_or_create!

Spree::MenuItem.where(
  name: 'Shirts And Blouses',
  linked_resource_type: 'URL',
  url: '/t/women/shirts-and-blouses',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_women
).first_or_create!

Spree::MenuItem.where(
  name: 'Sweaters',
  linked_resource_type: 'URL',
  url: '/t/women/sweaters',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_women
).first_or_create!

Spree::MenuItem.where(
  name: 'Tops and T-Shirts',
  linked_resource_type: 'URL',
  url: '/t/women/tops-and-t-shirts',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_women
).first_or_create!

Spree::MenuItem.where(
  name: 'Jackets and Coats',
  linked_resource_type: 'URL',
  url: '/t/women/jackets-and-coats',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_women
).first_or_create!

###############################
# Links For: MEN / CATAGORIES #
###############################
Spree::MenuItem.where(
  name: 'Shirts',
  linked_resource_type: 'URL',
  url: '/t/men/shirts',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_men
).first_or_create!

Spree::MenuItem.where(
  name: 'T-Shirts',
  linked_resource_type: 'URL',
  url: '/t/men/t-shirts',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_men
).first_or_create!

Spree::MenuItem.where(
  name: 'Sweaters',
  linked_resource_type: 'URL',
  url: '/t/men/sweaters',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_men
).first_or_create!

Spree::MenuItem.where(
  name: 'Jackets and Coats',
  linked_resource_type: 'URL',
  url: '/t/men/jackets-and-coats',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_men
).first_or_create!

######################################
# Links For: SPORTSWARE / CATAGORIES #
######################################
Spree::MenuItem.where(
  name: 'Tops',
  linked_resource_type: 'URL',
  url: '/t/sportswear/tops',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_sw
).first_or_create!

Spree::MenuItem.where(
  name: 'Sweatshirts',
  linked_resource_type: 'URL',
  url: '/t/sportswear/sweatshirts',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_sw
).first_or_create!

Spree::MenuItem.where(
  name: 'Pants',
  linked_resource_type: 'URL',
  url: '/t/sportswear/pants',
  item_type: 'Link',
  menu_id: main_menu,
  parent_id: main_menu_cat_sw
).first_or_create!
