object @line_item
attributes :quantity, :price
child :variant do
  extends "variants/variant"
end
