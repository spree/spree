Jbuilder.encode do |json|
  json.array! @products do |product|
    json.name product.name
  end
end