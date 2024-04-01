Spree::Sample.load_sample('taxons')
Spree::Sample.load_sample('products')

men_tshirts_properties = [
  {
    "виробник"=>"Wilson",
    "бренд"=>"Wannabe Sports",
    "модель"=>"JK1002",
    "тип_сорочки"=>"Бейсбольна майка",
    "тип_рукава"=>"Довгий",
    "матеріал"=>"100% Бавовна",
    "формат"=>"Вільний",
    "стать"=>"Чоловіча"
  },
  {
    "виробник"=>"Jerseys",
    "бренд"=>"Conditioned",
    "модель"=>"TL9002",
    "тип_сорочки"=>"Майка Ringer",
    "тип_рукава"=>"Короткий",
    "матеріал"=>"100% Велюр",
    "формат"=>"Вільний",
    "стать"=>"Чоловіча"
  },
  {
    "виробник"=>"Wilson",
    "бренд"=>"Wannabe Sports",
    "модель"=>"JK1002",
    "тип_сорочки"=>"Бейсбольна майка",
    "тип_рукава"=>"Довгий",
    "матеріал"=>"100% бавовна",
    "формат"=>"Вільний",
    "стать"=>"Чоловіча"
  },
  {
    "виробник"=>"Jerseys",
    "бренд"=>"Conditioned",
    "модель"=>"TL9002",
    "тип_сорочки"=>"Майка Ringer",
    "тип_рукава"=>"Короткий",
    "матеріал"=>"100% Велюр",
    "формат"=>"Вільний",
    "стать"=>"Чоловіча"
  }
]

Spree::Taxon.find_by!(name: 'Чоловіки').children.find_by!(name: 'Футболки').products.each do |product|
  men_tshirts_properties.sample.each do |prop_name, prop_value|
    product.set_property(prop_name, prop_value, prop_name.gsub('_', ' ').capitalize)
  end
end

women_tshirts_properties = [
  {"виробник"=>"Jerseys",
  "бренд"=>"Resiliance",
  "модель"=>"TL174",
  "тип_сорочки"=>"Jr. Спагеті Т",
  "тип_рукава"=>"Відсутній",
  "матеріал"=>"90% Бавовна, 10% Нейлон",
  "формат"=>"Форма",
  "стать"=>"Жіноча"},
  {"виробник"=>"Jerseys",
  "бренд"=>"Resiliance",
  "модель"=>"TL174",
  "тип_сорочки"=>"Jr. Спагеті Т",
  "тип_рукава"=>"Відсутній",
  "матеріал"=>"90% Бавовна, 10% Нейлон",
  "формат"=>"Форма",
  "стать"=>"Жіноча"}
]

Spree::Taxon.find_by!(name: 'Жінки').children.find_by!(name: 'Топи і Футболки').products.each do |product|
  women_tshirts_properties.sample.each do |prop_name, prop_value|
    product.set_property(prop_name, prop_value, prop_name.gsub('_', ' ').capitalize)
  end
end

properties = {
  manufacturers: %w[Wilson Jerseys Wannabe Resiliance Conditioned],
  brands: %w[Puma Adidas Reebok Sinsay Zara Power Lacoste],
  materials: ['90% Бавовна, 10% Нейлон', '50% Бавовна 50%, Еластан', '10% Бавовна 90%, Еластан'],
  fits: %w[Форма Вільний]
}

t_shirts_taxon = Spree::Taxon.where(name: ['Футболки', 'Топи і Футболки'])

Spree::Product.all.each do |product|
  product.set_property("тип", product.taxons.first.name)
  product.set_property("колекція", product.taxons.first.name)

  next if product.taxons.include?(t_shirts_taxon)

  product.set_property("виробник", properties[:manufacturers].sample)
  product.set_property("бренд", properties[:brands].sample)
  product.set_property("матеріал", properties[:materials].sample)
  product.set_property("формат", properties[:fits].sample)
  product.set_property("стать", (product.taxons.pluck(:name).include?('Чоловіча') ? 'Чоловіки' : 'Жінки'))
  product.set_property("модель", product.sku)
end
