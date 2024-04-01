MENUS = []

Spree::Menu.all.each do |menu|
  MENUS << menu
end

def image(filename)
  picture = Spree::Icon.new
  file = File.open(File.join(__dir__, "images", "menu_items", filename))
  picture.attachment.attach(io: file, filename:, content_type: 'image/jpg')
  picture
end

MENUS.each do |menu|
  ################
  # Translations #
  ################
  case menu.locale
  when 'en'
    root_name_a = 'Women'
    root_name_b = 'Men'
    root_name_c = 'Sportswear'

    categories = 'Categories'

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
  when 'uk'
    root_name_a = 'Жінки'
    root_name_b = 'Чоловіки'
    root_name_c = 'Спортивний одяг'

    categories = 'Категорії'

    skirts = 'Спідниці'
    dresses = 'Сукні'
    shirts_and_blouses = 'Спідниці та Блузки'
    sweaters = 'Светри'
    tops_and_t_shirts = 'Топи та Футболки'
    jackets_and_coats = 'Куртки та Пальто'
    shirts = 'Сорочки'
    t_shirts = 'Футболки'
    tops = 'Топи'
    sweat_shirts = 'Світшоти'
    pants = 'Штани'

    promo_a_name = 'Нова Колекція'
    promo_a_subtitle = "Літо #{Date.today.year}"

    promo_b_name = 'Спеціальні Пропозиції'
    promo_b_subtitle = 'Отримайте знижку до 30%'
  end

  ##############
  # Root Items #
  ##############
  woman_taxon = Spree::Taxon.find_by!(permalink: 'katieghoriyi/zhinki')
  menu_root_women = Spree::MenuItem.where(
    name: root_name_a,
    item_type: 'Link',
    linked_resource_type: 'Spree::Taxon',
    menu_id: menu,
    parent_id: menu.root.id
  ).first_or_create!
  menu_root_women.linked_resource_id = woman_taxon.id
  menu_root_women.save!

  men_taxon = Spree::Taxon.find_by!(permalink: 'katieghoriyi/choloviki')
  menu_root_men = Spree::MenuItem.where(
    name: root_name_b,
    item_type: 'Link',
    linked_resource_type: 'Spree::Taxon',
    menu_id: menu,
    parent_id: menu.root.id
  ).first_or_create!
  menu_root_men.linked_resource_id = men_taxon.id
  menu_root_men.save!

  sw_taxon = Spree::Taxon.find_by!(permalink: 'katieghoriyi/sportivnii-odiagh')
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
      name: categories,
      item_type: 'Container',
      code: 'category',
      menu_id: menu,
      parent_id: menu_root_women
    ).first_or_create!

    menu_cat_men = Spree::MenuItem.where(
      name: categories,
      item_type: 'Container',
      code: 'category',
      menu_id: menu,
      parent_id: menu_root_men
    ).first_or_create!

    menu_cat_sw = Spree::MenuItem.where(
      name: categories,
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

  summer = Spree::Taxon.find_by!(permalink: "katieghoriyi/nova-koliektsiia/lito-#{Date.today.year}")
  offers = Spree::Taxon.find_by!(permalink: 'katieghoriyi/spietsialni-propozitsiyi/znizhka-30-percent')

  #####################
  # Links For: PROMOS #
  #####################

  promos.each do |promo|
    summer_promo = Spree::MenuItem.where(
      name: promo_a_name,
      subtitle: promo_a_subtitle,
      linked_resource_type: 'Spree::Taxon',
      item_type: 'Link',
      menu_id: menu,
      parent_id: promo
    ).first_or_create!
    summer_promo.linked_resource_id = summer.id
    summer_promo.icon = image("new_collection.jpg")
    summer_promo.save!

    special_offer = Spree::MenuItem.where(
      name: promo_b_name,
      subtitle: promo_b_subtitle,
      linked_resource_type: 'Spree::Taxon',
      item_type: 'Link',
      menu_id: menu,
      parent_id: promo
    ).first_or_create!
    special_offer.linked_resource_id = offers.id
    special_offer.icon = image("spec_propositions.jpg")
    special_offer.save!
  end

  #################################
  # Links For: WOMEN / CATEGORIES #
  #################################

  women_link_parent_id = if menu.location == 'header'
                           menu_cat_women
                         else
                           menu_root_women
                         end

  women_skirts_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/zhinki/spidnitsi')
  women_skirts = Spree::MenuItem.where(
    name: skirts,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_skirts.linked_resource_id = women_skirts_t.id
  women_skirts.save!

  women_dresses_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/zhinki/sukni')
  women_dresses = Spree::MenuItem.where(
    name: dresses,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_dresses.linked_resource_id = women_dresses_t.id
  women_dresses.save!

  women_s_b_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/zhinki/sorochki-ta-bluzki')
  women_s_b = Spree::MenuItem.where(
    name: shirts_and_blouses,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_s_b.linked_resource_id = women_s_b_t.id
  women_s_b.save!

  women_sweaters_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/zhinki/svietri')
  women_sweaters = Spree::MenuItem.where(
    name: sweaters,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_sweaters.linked_resource_id = women_sweaters_t.id
  women_sweaters.save!

  women_tops_tees_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/zhinki/topi-i-futbolki')
  women_tops_tees = Spree::MenuItem.where(
    name: tops_and_t_shirts,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: women_link_parent_id
  ).first_or_create!
  women_tops_tees.linked_resource_id = women_tops_tees_t.id
  women_tops_tees.save!

  women_j_c_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/zhinki/kurtki-ta-palto')
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
  # Links For: MEN / CATEGORIES #
  ###############################

  men_link_parent_id = if menu.location == 'header'
                         menu_cat_men
                       else
                         menu_root_men
                       end

  men_shirts_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/choloviki/sorochki')
  men_shirts = Spree::MenuItem.where(
    name: shirts,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: men_link_parent_id
  ).first_or_create!
  men_shirts.linked_resource_id = men_shirts_t.id
  men_shirts.save!

  men_t_shirts_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/choloviki/futbolki')
  men_t_shirts = Spree::MenuItem.where(
    name: t_shirts,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: men_link_parent_id
  ).first_or_create!
  men_t_shirts.linked_resource_id = men_t_shirts_t.id
  men_t_shirts.save!

  men_sweaters_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/choloviki/svietri')
  men_sweaters = Spree::MenuItem.where(
    name: sweaters,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: men_link_parent_id
  ).first_or_create!
  men_sweaters.linked_resource_id = men_sweaters_t.id
  men_sweaters.save!

  men_j_c_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/choloviki/kurtki-ta-palto')
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
  # Links For: SPORTSWARE / CATEGORIES #
  ######################################

  sw_link_parent_id = if menu.location == 'header'
                        menu_cat_sw
                      else
                        menu_root_sw
                      end

  sw_tops_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/sportivnii-odiagh/topi')
  sw_tops = Spree::MenuItem.where(
    name: tops,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: sw_link_parent_id
  ).first_or_create!
  sw_tops.linked_resource_id = sw_tops_t.id
  sw_tops.save!

  sw_sweatshirts_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/sportivnii-odiagh/svitshoti')
  sw_sweatshirts = Spree::MenuItem.where(
    name: sweat_shirts,
    linked_resource_type: 'Spree::Taxon',
    item_type: 'Link',
    menu_id: menu,
    parent_id: sw_link_parent_id
  ).first_or_create!
  sw_sweatshirts.linked_resource_id = sw_sweatshirts_t.id
  sw_sweatshirts.save!

  sw_pants_t = Spree::Taxon.find_by!(permalink: 'katieghoriyi/sportivnii-odiagh/shtani')
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
