products =
  { 
    "חלב תנובה" => 
    { 
      "יצרן" => "תנובה",
      "משקל" => "1 ליטר",
    },
    "יוגורט 1.5% טרה" =>
    {
      "יצרן" => "טרה",
    }
  }

products.each do |name, properties|
  product = Spree::Product.find_by_name(name)
  properties.each do |prop_name, prop_value|
    product.set_property(prop_name, prop_value)
  end
end
