Spree::Sample.load_sample("taxonomies")
Spree::Sample.load_sample("products")

categories = Spree::Taxonomy.find_by_name!("מחלקות")
#on_promotion = Spree::Taxonomy.find_by_name!("מוצרים במבצע")

products = { 
  :ror_milk_tnuva => "חלב תנובה",
  :ror_yogurt => "יוגורט 1.5% טרה",
  :ror_milk_yot => "חלב עמיד יטבתה",
  
  :ror_bread => "לחם פרוס ברמן",
  :ror_pasta => "ספגטי פרפקטו אסם",
  :spree_baflim => "מנעמים מצופים שוקולד",
  :spree_mana => "מנה חמה אסם",
  :apache_corn_s => "שניצל תירס",
  
  :ruby_coffee => "קפס נמס עלית",
  :spree_olive_oil => "שמן זית",
  
  :ror_wet_napkins => "מטליות לחות לירן",
  :ror_tp => "נייר טואלט עלילי",
  :spree_napkins =>  "מפיות שולחן",
  
  :spree_juice_tom => "מיץ עגבניות פריגת",
  :spree_beer => "בירה מכבי",
  
  :spree_dogli => "אוכל לכלבים",
  :spree_baby => "מטרנה"
}


products.each do |key, name|
  products[key] = Spree::Product.find_by_name!(name)
end

taxons = [
  {
    :name => "מחלקות",
    :taxonomy => categories,
    :position => 0
  },
  {
    :name => "מוצרי חלב",
    :taxonomy => categories,
    :parent => "מחלקות",
    :position => 1,
    :products => [
      products[:ror_milk_tnuva],
      products[:ror_yogurt],
      products[:ror_milk_yot]
    ]
  },
  {
    :name => "מוצרי בסיס",
    :taxonomy => categories,
    :parent => "מחלקות",
    :position => 2,
    :products => [
      products[:ror_bread],
      products[:ror_pasta],
      products[:spree_baflim],
      products[:spree_mana],
      products[:apache_corn_s]
    ]
  },
  {
    :name => "מוצרים לבית",
    :taxonomy => categories,
    :parent => "מחלקות",
    :position => 2,
    :products => [
      products[:ror_wet_napkins],
      products[:ror_tp],
      products[:spree_napkins],
    ]
  },
  {
    :name => "שונות",
    :taxonomy => categories,
    :parent => "מחלקות",
    :position => 2,
    :products => [
      products[:spree_dogli],
      products[:spree_baby],
      products[:spree_napkins],
      products[:ruby_coffee],
      products[:spree_olive_oil]
    ]
  },
  {
    :name => "שתייה",
    :taxonomy => categories,
    :parent => "מחלקות" 
  },
  {
    :name => "שתייה קלה",
    :taxonomy => categories,
    :parent => "שתייה",
    :position => 0,
    :products => [
      products[:spree_juice_tom]
    ]
  },
  {
    :name => "שתייה חריפה",
    :taxonomy => categories,
    :parent => "שתייה" ,
    :products => [
      products[:spree_beer]
    ],
    :position => 0
  },
]

taxons.each do |taxon_attrs|
  if taxon_attrs[:parent]
    taxon_attrs[:parent] = Spree::Taxon.find_by_name!(taxon_attrs[:parent])
    Spree::Taxon.create!(taxon_attrs)
  end
end
