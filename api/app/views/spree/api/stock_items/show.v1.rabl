object @stock_item
attributes *stock_item_attributes
child(:variant) do
  attributes :name, :id, :sku
end
