MENUS = []

Spree::Menu.all.each do |menu|
  MENUS << menu
end

MENUS.each do |menu|
  ################
  # Translations #
  ################
  case menu.locale
  when 'en'
    root_name_a = 'Women'
    root_name_b = 'Men'
    root_name_c = 'Sportsware'

    catagories = 'Categories'

    skirts = 'Skirts'
    dresses = 'Dresses'
    shirts_and_blouses = 'Skirts and Blouses'
    sweaters = 'Sweaters'
    tops_and_t_shirts = 'Tops and T-Shirts'
    jackets_and_coats = 'Jackets and Coats'
    shirts = 'Shirts'
    t_shirts = 'T-Shirts'
    tops = 'Tops'
    sweat_shirts = 'Sweatshirts'
    pants = 'Pants'

    promo_a_name = 'New Collection'
    promo_a_subtitle = "Summer #{Date.today.year}"

    promo_b_name = 'Special Offers'
    promo_b_subtitle = 'Get up to 30% off'

  when 'fr'
    root_name_a = 'Femmes'
    root_name_b = 'Hommes'
    root_name_c = 'Vêtements de sport'

    catagories = 'Catégories'

    skirts = 'Jupes'
    dresses = 'Robes'
    shirts_and_blouses = 'Jupes et chemisiers'
    sweaters = 'Chandails'
    tops_and_t_shirts = 'Hauts et T-shirts'
    jackets_and_coats = 'Vestes et manteaux'
    shirts = 'Chemises'
    t_shirts = 'T-Shirts'
    tops = 'Hauts'
    sweat_shirts = 'Pulls molletonnés'
    pants = 'Pantalon'

    promo_a_name = 'Nouvelle collection'
    promo_a_subtitle = "Été #{Date.today.year}"

    promo_b_name = 'Offres spéciales'
    promo_b_subtitle = "Obtenez jusqu'à 30% de réduction"

  when 'de'
    root_name_a = 'Frauen'
    root_name_b = 'Männer'
    root_name_c = 'Sportartikel'

    catagories = 'Kategorien'

    skirts = 'die Röcke'
    dresses = 'Kleider'
    shirts_and_blouses = 'Röcke und Blusen'
    sweaters = 'Pullovers'
    tops_and_t_shirts = 'Tops und T-Shirts'
    jackets_and_coats = 'Jacken und Mäntel'
    shirts = 'Hemden'
    t_shirts = 'T-Shirts'
    tops = 'Tops'
    sweat_shirts = 'Sweatshirts'
    pants = 'Hose'

    promo_a_name = 'Neue Kollektion'
    promo_a_subtitle = "Sommer #{Date.today.year}"

    promo_b_name = 'Sonderangebote'
    promo_b_subtitle = 'Erhalten Sie bis zu 30% Rabatt'

  when 'es'
    root_name_a = 'Hombres'
    root_name_b = 'Mujeres'
    root_name_c = 'Deportes'

    catagories = 'Categorías'

    skirts = 'Faldas'
    dresses = 'Vestidos'
    shirts_and_blouses = 'Faldas y blusas'
    sweaters = 'Suéteres'
    tops_and_t_shirts = 'Tops y camisetas'
    jackets_and_coats = 'Chaquetas y abrigos'
    shirts = 'Camisas'
    t_shirts = 'Camisetas'
    tops = 'Tops'
    sweat_shirts = 'Sudaderas'
    pants = 'Pantalones'

    promo_a_name = 'Nueva colección'
    promo_a_subtitle = "Verano #{Date.today.year}"

    promo_b_name = 'Ofertas especiales'
    promo_b_subtitle = 'Obtenga hasta un 30% de descuento'
  end

  ##############
  # Root Items #
  ##############
  woman_taxon = Spree::Taxon.find_by!(permalink: 'women')
  menu_root_women = Spree::MenuItem.where(
    name: root_name_a,
    item_type: 'Link',
    linked_resource_type: 'Spree::Taxon',
    menu_id: menu,
    parent_id: menu.root.id
  ).first_or_create!
  menu_root_women.linked_resource_id = woman_taxon.id
  menu_root_women.save!

  men_taxon = Spree::Taxon.find_by!(permalink: 'men')
  menu_root_men = Spree::MenuItem.where(
    name: root_name_b,
    item_type: 'Link',
    linked_resource_type: 'Spree::Taxon',
    menu_id: menu,
    parent_id: menu.root.id
  ).first_or_create!
  menu_root_men.linked_resource_id = men_taxon.id
  menu_root_men.save!

  sw_taxon = Spree::Taxon.find_by!(permalink: 'sportswear')
  menu_root_sw = Spree::MenuItem.where(
    name: root_name_c,
    item_type: 'Link',
    linked_resource_type: 'Spree::Taxon',
    menu_id: menu,
    parent_id: menu.root.id
  ).first_or_create!
  menu_root_sw.linked_resource_id = sw_taxon.id
  menu_root_sw.save!

  if menu.location == 'header'
    ## Only For Header Menu
    ##############
    # Categories #
    ##############
    menu_cat_women = Spree::MenuItem.where(
      name: catagories,
      item_type: 'Container',
      code: 'category',
      menu_id: menu,
      parent_id: menu_root_women
    ).first_or_create!

    menu_cat_men = Spree::MenuItem.where(
      name: catagories,
      item_type: 'Container',
      code: 'category',
      menu_id: menu,
      parent_id: menu_root_men
    ).first_or_create!

    menu_cat_sw = Spree::MenuItem.where(
      name: catagories,
      item_type: 'Container',
      code: 'category',
      menu_id: menu,
      parent_id: menu_root_sw
    ).first_or_create!

    ##############
    # Promotions #
    ##############
    menu_promo_women = Spree::MenuItem.where(
      name: 'Promos',
      item_type: 'Container',
      code: 'promo',
      menu_id: menu,
      parent_id: menu_root_women
    ).first_or_create!

    menu_promo_men = Spree::MenuItem.where(
      name: 'Promos',
      item_type: 'Container',
      code: 'promo',
      menu_id: menu,
      parent_id: menu_root_men
    ).first_or_create!

    menu_promo_sw = Spree::MenuItem.where(
      name: 'Promos',
      item_type: 'Container',
      code: 'promo',
      menu_id: menu,
      parent_id: menu_root_sw
    ).first_or_create!

    promos = [menu_promo_women, menu_promo_men, menu_promo_sw]
  else
    promos = []
  end

  summer = Spree::Taxon.find_by!(permalink: 'new-collection/summer-2021')
  offers = Spree::Taxon.find_by!(permalink: 'special-offers/30-percent-off')

  #####################
  # Links For: PROMOS #
  #####################

  promos.each do |promo|
    summer_promo = Spree::MenuItem.where(
      name: promo_a_name,
      subtitle: promo_a_subtitle,
      linked_resource_type: 'Spree::Taxon',
      item_type: 'Container',
      menu_id: menu,
      parent_id: promo
    ).first_or_create!
    summer_promo.linked_resource_id = summer.id
    summer_promo.save!

    special_offer = Spree::MenuItem.where(
      name: promo_b_name,
      subtitle: promo_b_subtitle,
      linked_resource_type: 'Spree::Taxon',
      item_type: 'Container',
      menu_id: menu,
      parent_id: promo
    ).first_or_create!
    special_offer.linked_resource_id = offers.id
    special_offer.save!
  end

  #################################
  # Links For: WOMEN / CATAGORIES #
  #################################

  women_link_parent_id = if menu.location == 'header'
                           menu_cat_women
                         else
                           menu_root_women
                         end

  women_skirts_t = Spree::Taxon.find_by!(permalink: 'women/skirts')
  women_skirts = Spree::MenuItem.where(
    name: skirts,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_skirts.linked_resource_id = women_skirts_t.id
  women_skirts.save!

  women_dresses_t = Spree::Taxon.find_by!(permalink: 'women/dresses')
  women_dresses = Spree::MenuItem.where(
    name: dresses,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_dresses.linked_resource_id = women_dresses_t.id
  women_dresses.save!

  women_s_b_t = Spree::Taxon.find_by!(permalink: 'women/shirts-and-blouses')
  women_s_b = Spree::MenuItem.where(
    name: shirts_and_blouses,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_s_b.linked_resource_id = women_s_b_t.id
  women_s_b.save!

  women_sweaters_t = Spree::Taxon.find_by!(permalink: 'women/sweaters')
  women_sweaters = Spree::MenuItem.where(
    name: sweaters,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_sweaters.linked_resource_id = women_sweaters_t.id
  women_sweaters.save!

  women_tops_tees_t = Spree::Taxon.find_by!(permalink: 'women/tops-and-t-shirts')
  women_tops_tees = Spree::MenuItem.where(
    name: tops_and_t_shirts,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_tops_tees.linked_resource_id = women_tops_tees_t.id
  women_tops_tees.save!

  women_j_c_t = Spree::Taxon.find_by!(permalink: 'women/jackets-and-coats')
  women_j_c = Spree::MenuItem.where(
    name: jackets_and_coats,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_j_c.linked_resource_id = women_j_c_t.id
  women_j_c.save!

  ###############################
  # Links For: MEN / CATAGORIES #
  ###############################

  men_link_parent_id = if menu.location == 'header'
                         menu_cat_men
                       else
                         menu_root_men
                       end

  men_shirts_t = Spree::Taxon.find_by!(permalink: 'men/shirts')
  men_shirts = Spree::MenuItem.where(
    name: shirts,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: men_link_parent_id
  ).first_or_create!
  men_shirts.linked_resource_id = men_shirts_t.id
  men_shirts.save!

  men_t_shirts_t = Spree::Taxon.find_by!(permalink: 'men/t-shirts')
  men_t_shirts = Spree::MenuItem.where(
    name: t_shirts,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: men_link_parent_id
  ).first_or_create!
  men_t_shirts.linked_resource_id = men_t_shirts_t.id
  men_t_shirts.save!

  men_sweaters_t = Spree::Taxon.find_by!(permalink: 'men/sweaters')
  men_sweaters = Spree::MenuItem.where(
    name: sweaters,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: men_link_parent_id
  ).first_or_create!
  men_sweaters.linked_resource_id = men_sweaters_t.id
  men_sweaters.save!

  men_j_c_t = Spree::Taxon.find_by!(permalink: 'men/jackets-and-coats')
  men_j_c = Spree::MenuItem.where(
    name: jackets_and_coats,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: men_link_parent_id
  ).first_or_create!
  men_j_c.linked_resource_id = men_j_c_t.id
  men_j_c.save!

  ######################################
  # Links For: SPORTSWARE / CATAGORIES #
  ######################################

  sw_link_parent_id = if menu.location == 'header'
                        menu_cat_sw
                      else
                        menu_root_sw
                      end

  sw_tops_t = Spree::Taxon.find_by!(permalink: 'sportswear/tops')
  sw_tops = Spree::MenuItem.where(
    name: tops,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: sw_link_parent_id
  ).first_or_create!
  sw_tops.linked_resource_id = sw_tops_t.id
  sw_tops.save!

  sw_sweatshirts_t = Spree::Taxon.find_by!(permalink: 'sportswear/sweatshirts')
  sw_sweatshirts = Spree::MenuItem.where(
    name: sweat_shirts,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: sw_link_parent_id
  ).first_or_create!
  sw_sweatshirts.linked_resource_id = sw_sweatshirts_t.id
  sw_sweatshirts.save!

  sw_pants_t = Spree::Taxon.find_by!(permalink: 'sportswear/pants')
  sw_pants = Spree::MenuItem.where(
    name: pants,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: sw_link_parent_id
  ).first_or_create!
  sw_pants.linked_resource_id = sw_pants_t.id
  sw_pants.save!
end
