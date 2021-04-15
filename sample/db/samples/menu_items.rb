main_menu = Spree::Menu.find_by!(name: 'Main Menu')
footer_menu = Spree::Menu.find_by!(name: 'Footer Menu')

MENUS = [main_menu, footer_menu]

MENUS.each do |menu_id|
  ##############
  # Root Items #
  ##############
  woman_taxon = Spree::Taxon.find_by!(permalink: 'women')
  menu_root_women = Spree::MenuItem.where(
    name: 'Women',
    item_type: 'Link',
    linked_resource_type: 'Taxon',
    menu_id: menu_id
  ).first_or_create!
  menu_root_women.linked_resource_id = woman_taxon.id
  menu_root_women.save!

  men_taxon = Spree::Taxon.find_by!(permalink: 'men')
  menu_root_men = Spree::MenuItem.where(
    name: 'Men',
    item_type: 'Link',
    linked_resource_type: 'Taxon',
    menu_id: menu_id
  ).first_or_create!
  menu_root_men.linked_resource_id = men_taxon.id
  menu_root_men.save!

  sw_taxon = Spree::Taxon.find_by!(permalink: 'sportswear')
  menu_root_sw = Spree::MenuItem.where(
    name: 'Sportsware',
    item_type: 'Link',
    linked_resource_type: 'Taxon',
    menu_id: menu_id
  ).first_or_create!
  menu_root_sw.linked_resource_id = sw_taxon.id
  menu_root_sw.save!

  ##############
  # Catagories #
  ##############
  menu_cat_women = Spree::MenuItem.where(
    name: 'Catagories',
    item_type: 'Container',
    menu_id: menu_id,
    parent_id: menu_root_women
  ).first_or_create!

  menu_cat_men = Spree::MenuItem.where(
    name: 'Catagories',
    item_type: 'Container',
    menu_id: menu_id,
    parent_id: menu_root_men
  ).first_or_create!

  menu_cat_sw = Spree::MenuItem.where(
    name: 'Catagories',
    item_type: 'Container',
    menu_id: menu_id,
    parent_id: menu_root_sw
  ).first_or_create!

  ##############
  # Promotions #
  ##############
  menu_promo_women = Spree::MenuItem.where(
    name: 'Promos',
    item_type: 'Container',
    menu_id: menu_id,
    parent_id: menu_root_women
  ).first_or_create!

  menu_promo_men = Spree::MenuItem.where(
    name: 'Promos',
    item_type: 'Container',
    menu_id: menu_id,
    parent_id: menu_root_men
  ).first_or_create!

  menu_promo_sw = Spree::MenuItem.where(
    name: 'Promos',
    item_type: 'Container',
    menu_id: menu_id,
    parent_id: menu_root_sw
  ).first_or_create!

  promos = [menu_promo_women, menu_promo_men, menu_promo_sw]
  summer = Spree::Taxon.find_by!(permalink: 'new-collection/summer-2021')
  offers = Spree::Taxon.find_by!(permalink: 'special-offers/30-percent-off')

  #####################
  # Links For: PROMOS #
  #####################
  promos.each do |promo|
    summer_promo = Spree::MenuItem.where(
      name: 'New Collection',
      subtitle: "Summer #{Date.today.year}",
      linked_resource_type: 'Taxon',
      item_type: 'Promotion',
      menu_id: menu_id,
      parent_id: promo
    ).first_or_create!
    summer_promo.linked_resource_id = summer.id
    summer_promo.save!

    special_offer = Spree::MenuItem.where(
      name: 'Special Offers',
      subtitle: 'Get up to 30% OFF',
      linked_resource_type: 'Taxon',
      item_type: 'Promotion',
      menu_id: menu_id,
      parent_id: promo
    ).first_or_create!
    special_offer.linked_resource_id = offers.id
    special_offer.save!
  end

  #################################
  # Links For: WOMEN / CATAGORIES #
  #################################
  women_skirts_t = Spree::Taxon.find_by!(permalink: 'women/skirts')
  women_skirts = Spree::MenuItem.where(
    name: 'Skirts',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_women
  ).first_or_create!
  women_skirts.linked_resource_id = women_skirts_t.id
  women_skirts.save!

  women_dresses_t = Spree::Taxon.find_by!(permalink: 'women/dresses')
  women_dresses = Spree::MenuItem.where(
    name: 'Dresses',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_women
  ).first_or_create!
  women_dresses.linked_resource_id = women_dresses_t.id
  women_dresses.save!

  women_s_b_t = Spree::Taxon.find_by!(permalink: 'women/shirts-and-blouses')
  women_s_b = Spree::MenuItem.where(
    name: 'Shirts And Blouses',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_women
  ).first_or_create!
  women_s_b.linked_resource_id = women_s_b_t.id
  women_s_b.save!

  women_sweaters_t = Spree::Taxon.find_by!(permalink: 'women/sweaters')
  women_sweaters = Spree::MenuItem.where(
    name: 'Sweaters',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_women
  ).first_or_create!
  women_sweaters.linked_resource_id = women_sweaters_t.id
  women_sweaters.save!

  women_tops_tees_t = Spree::Taxon.find_by!(permalink: 'women/tops-and-t-shirts')
  women_tops_tees = Spree::MenuItem.where(
    name: 'Tops and T-Shirts',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_women
  ).first_or_create!
  women_tops_tees.linked_resource_id = women_tops_tees_t.id
  women_tops_tees.save!

  women_j_c_t = Spree::Taxon.find_by!(permalink: 'women/jackets-and-coats')
  women_j_c = Spree::MenuItem.where(
    name: 'Jackets and Coats',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_women
  ).first_or_create!
  women_j_c.linked_resource_id = women_j_c_t.id
  women_j_c.save!

  ###############################
  # Links For: MEN / CATAGORIES #
  ###############################
  men_shirts_t = Spree::Taxon.find_by!(permalink: 'men/shirts')
  men_shirts = Spree::MenuItem.where(
    name: 'Shirts',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_men
  ).first_or_create!
  men_shirts.linked_resource_id = men_shirts_t.id
  men_shirts.save!

  men_t_shirts_t = Spree::Taxon.find_by!(permalink: 'men/t-shirts')
  men_t_shirts = Spree::MenuItem.where(
    name: 'T-Shirts',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_men
  ).first_or_create!
  men_t_shirts.linked_resource_id = men_t_shirts_t.id
  men_t_shirts.save!

  men_sweaters_t = Spree::Taxon.find_by!(permalink: 'men/sweaters')
  men_sweaters = Spree::MenuItem.where(
    name: 'Sweaters',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_men
  ).first_or_create!
  men_sweaters.linked_resource_id = men_sweaters_t.id
  men_sweaters.save!

  men_j_c_t = Spree::Taxon.find_by!(permalink: 'men/jackets-and-coats')
  men_j_c = Spree::MenuItem.where(
    name: 'Jackets and Coats',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_men
  ).first_or_create!
  men_j_c.linked_resource_id = men_j_c_t.id
  men_j_c.save!

  ######################################
  # Links For: SPORTSWARE / CATAGORIES #
  ######################################
  sw_tops_t = Spree::Taxon.find_by!(permalink: 'sportswear/tops')
  sw_tops = Spree::MenuItem.where(
    name: 'Tops',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_sw
  ).first_or_create!
  sw_tops.linked_resource_id = sw_tops_t.id
  sw_tops.save!

  sw_sweatshirts_t = Spree::Taxon.find_by!(permalink: 'sportswear/sweatshirts')
  sw_sweatshirts = Spree::MenuItem.where(
    name: 'Sweatshirts',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_sw
  ).first_or_create!
  sw_sweatshirts.linked_resource_id = sw_sweatshirts_t.id
  sw_sweatshirts.save!

  sw_pants_t = Spree::Taxon.find_by!(permalink: 'sportswear/pants')
  sw_pants = Spree::MenuItem.where(
    name: 'Pants',
    linked_resource_type: 'Taxon',
    item_type: 'Link',
    menu_id: menu_id,
    parent_id: menu_cat_sw
  ).first_or_create!
  sw_pants.linked_resource_id = sw_pants_t.id
  sw_pants.save!
end
