object @line_item
attributes :quantity, :price
child :variant do
  attributes *variant_attributes
end
