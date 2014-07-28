# Spree::Sample.load_sample("option_values")
# Spree::Sample.load_sample("products")
#

ror_milk_tnuva =   Spree::Product.find_by_name!("חלב תנובה")
ror_yogurt =       Spree::Product.find_by_name!("יוגורט 1.5% טרה")
ror_milk_yot =     Spree::Product.find_by_name!("חלב עמיד יטבתה")
ror_bread =        Spree::Product.find_by_name!("לחם פרוס ברמן")
ror_pasta =        Spree::Product.find_by_name!("ספגטי פרפקטו אסם")
spree_baflim =     Spree::Product.find_by_name!("מנעמים מצופים שוקולד")
spree_mana =       Spree::Product.find_by_name!("מנה חמה אסם")
apache_corn_s =    Spree::Product.find_by_name!("שניצל תירס")
ruby_coffee =      Spree::Product.find_by_name!("קפס נמס עלית")
spree_olive_oil =  Spree::Product.find_by_name!("שמן זית")
ror_wet_napkins =  Spree::Product.find_by_name!("מטליות לחות לירן")
ror_tp =           Spree::Product.find_by_name!("נייר טואלט עלילי")
spree_napkins =    Spree::Product.find_by_name!("מפיות שולחן")
spree_juice_tom =  Spree::Product.find_by_name!("מיץ עגבניות פריגת")
spree_beer =       Spree::Product.find_by_name!("בירה מכבי")
spree_dogli =      Spree::Product.find_by_name!("אוכל לכלבים")
spree_baby =       Spree::Product.find_by_name!("מטרנה")

masters = {
  ror_milk_tnuva => {
    :sku => "ROR-001",
    :cost_price => 17,
  },
  ror_yogurt => {
    :sku => "ROR-00011",
    :cost_price => 17
  },
  ror_milk_yot => {
    :sku => "ROR-10012",
    :cost_price => 21
  },
  ror_bread => {
    :sku => "ROR-00013",
    :cost_price => 17
  },
  ror_pasta => {
    :sku => "ROR-00014",
    :cost_price => 11
  },
  spree_baflim => {
    :sku => "ROR-00015",
    :cost_price => 17
  },
  spree_mana => {
    :sku => "ROR-00016",
    :cost_price => 15
  },
  apache_corn_s => {
    :sku => "APC-00001",
    :cost_price => 17
  },
  ruby_coffee => {
    :sku => "RUB-00001",
    :cost_price => 17
  },
  spree_olive_oil => {
    :sku => "SPR-00001",
    :cost_price => 17
  },
  ror_wet_napkins => {
    :sku => "SPR-00016",
    :cost_price => 15
  },
  ror_tp => {
    :sku => "SPR-00013",
    :cost_price => 17
  },
  spree_napkins => {
    :sku => "SPR-00014",
    :cost_price => 11
  },
  spree_juice_tom => {
    :sku => "SPR-00015",
    :cost_price => 17
  },
  spree_beer => {
    :sku => "SPR-00011",
    :cost_price => 13
  },
  spree_dogli => {
    :sku => "SPR-00012",
    :cost_price => 21
  },
  spree_baby => {
    :sku => "SPR-00132",
    :cost_price => 21
  }
}

masters.each do |product, variant_attrs|
  product.master.update_attributes!(variant_attrs)
end

# ror_baseball_jersey = Spree::Product.find_by_name!("Ruby on Rails Baseball Jersey")
# ror_tote = Spree::Product.find_by_name!("Ruby on Rails Tote")
# ror_bag = Spree::Product.find_by_name!("Ruby on Rails Bag")
# ror_jr_spaghetti = Spree::Product.find_by_name!("Ruby on Rails Jr. Spaghetti")
# ror_mug = Spree::Product.find_by_name!("Ruby on Rails Mug")
# ror_ringer = Spree::Product.find_by_name!("Ruby on Rails Ringer T-Shirt")
# ror_stein = Spree::Product.find_by_name!("Ruby on Rails Stein")
# spree_baseball_jersey = Spree::Product.find_by_name!("Spree Baseball Jersey")
# spree_stein = Spree::Product.find_by_name!("Spree Stein")
# spree_jr_spaghetti = Spree::Product.find_by_name!("Spree Jr. Spaghetti")
# spree_mug = Spree::Product.find_by_name!("Spree Mug")
# spree_ringer = Spree::Product.find_by_name!("Spree Ringer T-Shirt")
# spree_tote = Spree::Product.find_by_name!("Spree Tote")
# spree_bag = Spree::Product.find_by_name!("Spree Bag")
# ruby_baseball_jersey = Spree::Product.find_by_name!("Ruby Baseball Jersey")
# apache_baseball_jersey = Spree::Product.find_by_name!("Apache Baseball Jersey")
#
# small = Spree::OptionValue.find_by_name!("Small")
# medium = Spree::OptionValue.find_by_name!("Medium")
# large = Spree::OptionValue.find_by_name!("Large")
# extra_large = Spree::OptionValue.find_by_name!("Extra Large")
#
# red = Spree::OptionValue.find_by_name!("Red")
# blue = Spree::OptionValue.find_by_name!("Blue")
# green = Spree::OptionValue.find_by_name!("Green")
#
# variants = [
#   {
#     :product => ror_baseball_jersey,
#     :option_values => [small, red],
#     :sku => "ROR-00001",
#     :cost_price => 17
#   },
#   {
#     :product => ror_baseball_jersey,
#     :option_values => [small, blue],
#     :sku => "ROR-00002",
#     :cost_price => 17
#   },
#   {
#     :product => ror_baseball_jersey,
#     :option_values => [small, green],
#     :sku => "ROR-00003",
#     :cost_price => 17
#   },
#   {
#     :product => ror_baseball_jersey,
#     :option_values => [medium, red],
#     :sku => "ROR-00004",
#     :cost_price => 17
#   },
#   {
#     :product => ror_baseball_jersey,
#     :option_values => [medium, blue],
#     :sku => "ROR-00005",
#     :cost_price => 17
#   },
#   {
#     :product => ror_baseball_jersey,
#     :option_values => [medium, green],
#     :sku => "ROR-00006",
#     :cost_price => 17
#   },
#   {
#     :product => ror_baseball_jersey,
#     :option_values => [large, red],
#     :sku => "ROR-00007",
#     :cost_price => 17
#   },
#   {
#     :product => ror_baseball_jersey,
#     :option_values => [large, blue],
#     :sku => "ROR-00008",
#     :cost_price => 17
#   },
#   {
#     :product => ror_baseball_jersey,
#     :option_values => [large, green],
#     :sku => "ROR-00009",
#     :cost_price => 17
#   },
#   {
#     :product => ror_baseball_jersey,
#     :option_values => [extra_large, green],
#     :sku => "ROR-00010",
#     :cost_price => 17
#   },
# ]
#

#
# Spree::Variant.create!(variants)
#