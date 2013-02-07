Spree::Sample.load_sample("option_values")
Spree::Sample.load_sample("products")

ror_baseball_jersey = Spree::Product.find_by_name!("Ruby on Rails Baseball Jersey")
ror_tote = Spree::Product.find_by_name!("Ruby on Rails Tote")
ror_bag = Spree::Product.find_by_name!("Ruby on Rails Bag")
ror_jr_spaghetti = Spree::Product.find_by_name!("Ruby on Rails Jr. Spaghetti")
ror_mug = Spree::Product.find_by_name!("Ruby on Rails Mug")
ror_ringer = Spree::Product.find_by_name!("Ruby on Rails Ringer T-Shirt")
ror_stein = Spree::Product.find_by_name!("Ruby on Rails Stein")
spree_baseball_jersey = Spree::Product.find_by_name!("Spree Baseball Jersey")
spree_stein = Spree::Product.find_by_name!("Spree Stein")
spree_jr_spaghetti = Spree::Product.find_by_name!("Spree Jr. Spaghetti")
spree_mug = Spree::Product.find_by_name!("Spree Mug")
spree_ringer = Spree::Product.find_by_name!("Spree Ringer T-Shirt")
spree_tote = Spree::Product.find_by_name!("Spree Tote")
spree_bag = Spree::Product.find_by_name!("Spree Bag")
ruby_baseball_jersey = Spree::Product.find_by_name!("Ruby Baseball Jersey")
apache_baseball_jersey = Spree::Product.find_by_name!("Apache Baseball Jersey")

small = Spree::OptionValue.find_by_name!("Small")
medium = Spree::OptionValue.find_by_name!("Medium")
large = Spree::OptionValue.find_by_name!("Large")
extra_large = Spree::OptionValue.find_by_name!("Extra Large")

red = Spree::OptionValue.find_by_name!("Red")
blue = Spree::OptionValue.find_by_name!("Blue")
green = Spree::OptionValue.find_by_name!("Green")

variants = [
  {
    :product => ror_baseball_jersey,
    :option_values => [small, red],
    :sku => "ROR-00001",
    :cost_price => 17
  },
  {
    :product => ror_baseball_jersey,
    :option_values => [small, blue],
    :sku => "ROR-00002",
    :cost_price => 17
  },
  {
    :product => ror_baseball_jersey,
    :option_values => [small, green],
    :sku => "ROR-00003",
    :cost_price => 17
  },
  {
    :product => ror_baseball_jersey,
    :option_values => [medium, red],
    :sku => "ROR-00004",
    :cost_price => 17
  },
  {
    :product => ror_baseball_jersey,
    :option_values => [medium, blue],
    :sku => "ROR-00005",
    :cost_price => 17
  },
  {
    :product => ror_baseball_jersey,
    :option_values => [medium, green],
    :sku => "ROR-00006",
    :cost_price => 17
  },
  {
    :product => ror_baseball_jersey,
    :option_values => [large, red],
    :sku => "ROR-00007",
    :cost_price => 17
  },
  {
    :product => ror_baseball_jersey,
    :option_values => [large, blue],
    :sku => "ROR-00008",
    :cost_price => 17
  },
  {
    :product => ror_baseball_jersey,
    :option_values => [large, green],
    :sku => "ROR-00009",
    :cost_price => 17
  },
  {
    :product => ror_baseball_jersey,
    :option_values => [extra_large, green],
    :sku => "ROR-00012",
    :cost_price => 17
  },
]

masters = {
  ror_baseball_jersey => {
    :sku => "ROR-001",
    :cost_price => 17,
  },
  ror_tote => {
    :sku => "ROR-00011",
    :cost_price => 17
  },
  ror_bag => {
    :sku => "ROR-00012",
    :cost_price => 21
  },
  ror_jr_spaghetti => {
    :sku => "ROR-00013",
    :cost_price => 17
  },
  ror_mug => {
    :sku => "ROR-00014",
    :cost_price => 11
  },
  ror_ringer => {
    :sku => "ROR-00015",
    :cost_price => 17
  },
  ror_stein => {
    :sku => "ROR-00016",
    :cost_price => 15
  },
  apache_baseball_jersey => {
    :sku => "APC-00001",
    :cost_price => 17
  },
  ruby_baseball_jersey => {
    :sku => "RUB-00001",
    :cost_price => 17
  },
  spree_baseball_jersey => {
    :sku => "SPR-00001",
    :cost_price => 17
  },
  spree_stein => {
    :sku => "SPR-00016",
    :cost_price => 15
  },
  spree_jr_spaghetti => {
    :sku => "SPR-00013",
    :cost_price => 17
  },
  spree_mug => {
    :sku => "SPR-00014",
    :cost_price => 11
  },
  spree_ringer => {
    :sku => "SPR-00015",
    :cost_price => 17
  },
  spree_tote => {
    :sku => "SPR-00011",
    :cost_price => 13
  },
  spree_bag => {
    :sku => "SPR-00012",
    :cost_price => 21
  }
}

Spree::Variant.create!(variants)

masters.each do |product, variant_attrs|
  product.master.update_attributes!(variant_attrs)
end
