Spree::Sample.load_sample("tax_categories")
Spree::Sample.load_sample("shipping_categories")

default_cat = Spree::TaxCategory.find_by_name!("ברירת מחדל")
shipping_category = Spree::ShippingCategory.find_by_name!("ברירת מחדל")

default_attrs = {
  :description => "בתחום השיווק, מוצר הוא כל דבר אשר ניתן להציע לשוק ואשר יספק את צרכי השוק. בתחום הייצור והתעשייה, נרכשים מוצרים כחומרי גלם (או מיוצרים בהליכי מיחזור) ונמכרים כסחורה מוגמרת. מצרכים הם בדרך כלל חומרי גלם (כמו מתכות ותוצרים חקלאיים), אבל מצרך יכול להיות נגיש גם לצרכן בשוק החופשי.",
  :available_on => Time.zone.now
}

products = [
  {
    :name => "חלב תנובה",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 15.99,
    :eur_price => 14
  },
  {
    :name => "יוגורט 1.5% טרה",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 22.99,
    :eur_price => 19
  },
  {
    :name => "לחם פרוס ברמן",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "ספגטי פרפקטו אסם",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 19.99,
    :eur_price => 16

  },
  {
    :name => "מטליות לחות לירן",
    :shipping_category => shipping_category,
    :tax_category => default_cat,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "נייר טואלט עלילי",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "חלב עמיד יטבתה",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "מנעמים מצופים שוקולד",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "מיץ עגבניות פריגת",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "מנה חמה אסם",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 19.99,
    :eur_price => 16
  },
  {
    :name => "מפיות שולחן",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 15.99,
    :eur_price => 14
  },
  {
    :name => "שמן זית",
    :tax_category => default_cat,
    :shipping_category => shipping_category,
    :price => 22.99,
    :eur_price => 19
  },
  {
    :name => "אוכל לכלבים",
    :shipping_category => shipping_category,
    :price => 13.99,
    :eur_price => 12
  },
  {
    :name => "מטרנה",
    :shipping_category => shipping_category,
    :price => 16.99,
    :eur_price => 14
  },
  {
    :name => "שניצל תירס",
    :shipping_category => shipping_category,
    :price => 16.99,
    :eur_price => 14
  },
  {
    :name => "קפה נמס עלית",
    :shipping_category => shipping_category,
    :price => 13.99,
    :eur_price => 12
  },
  {
    :name => "בירה מכבי",
    :shipping_category => shipping_category,
    :price => 13.99,
    :eur_price => 12
  },
]

products.each do |product_attrs|
  eur_price = product_attrs.delete(:eur_price)
  Spree::Config[:currency] = "ILS"

  default_shipping_category = Spree::ShippingCategory.find_by_name!("ברירת מחדל")
  product = Spree::Product.create!(default_attrs.merge(product_attrs))
  Spree::Config[:currency] = "EUR"
  product.reload
  product.price = eur_price
  product.shipping_category = default_shipping_category
  product.save!
end

Spree::Config[:currency] = "ILS"
