Spree::Sample.load_sample('tax_categories')
Spree::Sample.load_sample('shipping_categories')
Spree::Sample.load_sample('option_types')
Spree::Sample.load_sample('taxons')

default_shipping_category = Spree::ShippingCategory.find_by!(name: 'Default')
clothing_tax_category = Spree::TaxCategory.find_by!(name: 'Clothing')

Spree::Config[:currency] = 'USD'

color = Spree::OptionType.find_by!(name: 'color')
size = Spree::OptionType.find_by!(name: 'size')

PRODUCTS = [
  ["Men", "Shirts", "denim shirt"],
  ["Men", "Shirts", "checked shirt"],
  ["Men", "Shirts", "covered placket shirt"],
  ["Men", "Shirts", "slim fit shirt"],
  ["Men", "Shirts", "short sleeve shirt"],
  ["Men", "Shirts", "printed short sleeve shirt"],
  ["Men", "Shirts", "regular shirt"],
  ["Men", "Shirts", "checked slim fit shirt"],
  ["Men", "Shirts", "dotted shirt"],
  ["Men", "Shirts", "linen shirt"],
  ["Men", "Shirts", "regular shirt with rolled up sleeves"],
  ["Men", "T-shirts", "polo t-shirt"],
  ["Men", "T-shirts", "long sleeve t-shirt"],
  ["Men", "T-shirts", "3_4 sleeve t-shirt"],
  ["Men", "T-shirts", "t-shirt with holes"],
  ["Men", "T-shirts", "raw-edge t-shirt"],
  ["Men", "T-shirts", "v-neck t-shirt"],
  ["Men", "T-shirts", "tank top"],
  ["Men", "T-shirts", "basic t-shirt"],
  ["Men", "Sweaters", "high neck sweater"],
  ["Men", "Sweaters", "stripped jumper"],
  ["Men", "Sweaters", "long sleeve jumper with pocket"],
  ["Men", "Sweaters", "jumper"],
  ["Men", "Sweaters", "long sleeve sweatshirt"],
  ["Men", "Sweaters", "hoodie"],
  ["Men", "Sweaters", "zipped high neck sweater"],
  ["Men", "Sweaters", "long sleeve jumper"],
  ["Men", "Jackets and Coats", "suede biker jacket"],
  ["Men", "Jackets and Coats", "hooded jacket"],
  ["Men", "Jackets and Coats", "anorak with hood"],
  ["Men", "Jackets and Coats", "denim jacket"],
  ["Men", "Jackets and Coats", "wool-blend short coat"],
  ["Men", "Jackets and Coats", "down jacket with hood"],
  ["Men", "Jackets and Coats", "wool-blend coat"],
  ["Men", "Jackets and Coats", "jacket with liner"],
  ["Women", "Skirts", "flared midi skirt"],
  ["Women", "Skirts", "midi skirt with bottoms"],
  ["Women", "Skirts", "fitted skirt"],
  ["Women", "Skirts", "a-line suede skirt"],
  ["Women", "Skirts", "leather skirt with lacing"],
  ["Women", "Skirts", "flared skirt"],
  ["Women", "Skirts", "skater skirt"],
  ["Women", "Skirts", "skater short skirt"],
  ["Women", "Skirts", "floral flared skirt"],
  ["Women", "Skirts", "pleated skirt 2"],
  ["Women", "Dresses", "floral wrap dress"],
  ["Women", "Dresses", "v-neck floral maxi dress"],
  ["Women", "Dresses", "flared dress"],
  ["Women", "Dresses", "elegant flared dress"],
  ["Women", "Dresses", "long sleeve knitted dress"],
  ["Women", "Dresses", "striped shirt dress"],
  ["Women", "Dresses", "printed dress"],
  ["Women", "Dresses", "printed slit-sleeves dress"],
  ["Women", "Dresses", "dress with belt"],
  ["Women", "Dresses", "v-neck floral dress"],
  ["Women", "Dresses", "flounced dress"],
  ["Women", "Dresses", "slit maxi dress"],
  ["Women", "Shirts and Blouses", "semi-sheer shirt with floral cuffs"],
  ["Women", "Shirts and Blouses", "striped shirt"],
  ["Women", "Shirts and Blouses", "v-neck wide shirt"],
  ["Women", "Shirts and Blouses", "printed wrapped blouse"],
  ["Women", "Shirts and Blouses", "pleated sleeve v-neck shirt"],
  ["Women", "Shirts and Blouses", "cotton shirt"],
  ["Women", "Shirts and Blouses", "blouse with wide flounced sleeve"],
  ["Women", "Shirts and Blouses", "elegant blouse with chocker"],
  ["Women", "Shirts and Blouses", "floral shirt"],
  ["Women", "Shirts and Blouses", "semi-sheer shirt with pockets"],
  ["Women", "Shirts and Blouses", "v-neck shirt"],
  ["Women", "Shirts and Blouses", "printed shirt"],
  ["Women", "Sweaters", "asymetric sweater with wide sleeves"],
  ["Women", "Sweaters", "oversized knitted sweater"],
  ["Women", "Sweaters", "oversized sweatshirt"],
  ["Women", "Sweaters", "knitted high neck sweater"],
  ["Women", "Sweaters", "knitted v-neck sweater"],
  ["Women", "Sweaters", "long sleeve sweatshirt"],
  ["Women", "Sweaters", "cropped fitted sweater"],
  ["Women", "Tops and T-shirts", "crop top with tie"],
  ["Women", "Tops and T-shirts", "printed t-shirt"],
  ["Women", "Tops and T-shirts", "scrappy top"],
  ["Women", "Tops and T-shirts", "pleated sleeve t-shirt"],
  ["Women", "Tops and T-shirts", "scrappy crop top with tie"],
  ["Women", "Tops and T-shirts", "crop top"],
  ["Women", "Tops and T-shirts", "loose t-shirt with pocket imitation"],
  ["Women", "Tops and T-shirts", "sleeveless loose top"],
  ["Women", "Tops and T-shirts", "basic loose t-shirt"],
  ["Women", "Tops and T-shirts", "basic t-shirt"],
  ["Women", "Jackets and Coats", "coat with pockets"],
  ["Women", "Jackets and Coats", "long wool-blend coat with belt"],
  ["Women", "Jackets and Coats", "asymetric coat"],
  ["Women", "Jackets and Coats", "long coat with belt"],
  ["Women", "Jackets and Coats", "down jacket"],
  ["Women", "Jackets and Coats", "zipped jacket"],
  ["Women", "Jackets and Coats", "loose-fitted jacket"],
  ["Women", "Jackets and Coats", "double-breasted jacket"],
  ["Women", "Jackets and Coats", "leather biker jacket"],
  ["Women", "Jackets and Coats", "wool-blend coat with belt"],
  ["Women", "Jackets and Coats", "denim hooded jacket"],
  ["Women", "Jackets and Coats", "bomber jacket"],
  ["Sportswear", "Tops", "sports bra low support"],
  ["Sportswear", "Tops", "long sleeves yoga crop top"],
  ["Sportswear", "Tops", "oversize t-shirt wrapped on back"],
  ["Sportswear", "Tops", "long sleeves crop top"],
  ["Sportswear", "Tops", "laced crop top"],
  ["Sportswear", "Tops", "sports bra medium support"],
  ["Sportswear", "Tops", "sports bra "],
  ["Sportswear", "Tops", "sport cropp top"],
  ["Sportswear", "Sweatshirts", "running sweatshirt"],
  ["Sportswear", "Sweatshirts", "leightweight running jacket"],
  ["Sportswear", "Sweatshirts", "oversize sweatshirt"],
  ["Sportswear", "Sweatshirts", "sport windproof jacket"],
  ["Sportswear", "Sweatshirts", "sport waistcoat"],
  ["Sportswear", "Pants", "shined pants"],
  ["Sportswear", "Pants", "short pants"],
  ["Sportswear", "Pants", "printed pants with holes"],
  ["Sportswear", "Pants", "pants"],
  ["Sportswear", "Pants", "printed pants"],
  ["Sportswear", "Pants", "high waist pants with pockets"],
  ["Sportswear", "Pants", "high waist pants"]
]

PRODUCTS.each do |(parent_name, taxon_name, product_name)|
  parent = Spree::Taxon.find_by!(name: parent_name)
  taxon = parent.children.find_by!(name: taxon_name)
  taxon.products.where(name: product_name.titleize).first_or_create! do |product|
    product.price = rand(10...100) + 0.99
    product.description = FFaker::Lorem.paragraph
    product.available_on = Time.zone.now
    product.option_types = [color, size]
    product.shipping_category = default_shipping_category
    product.tax_category = clothing_tax_category
    product.sku = "#{product_name.delete(' ')}_#{product.price}"
    parent.products << product
  end
end

["Bestsellers", "New", "Trending", "Streetstyle", "Summer Sale"].each do |taxon_name|
  Spree::Taxon.find_by!(name: taxon_name).products << Spree::Product.all.sample(30)
end
