collection @products
attributes :sku, :name, :id 

child(:variant_images => :images) do
  attributes :mini_url
end
