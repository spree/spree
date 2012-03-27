object @line_item
attributes :quantity, :price
child :variant do
  extends "spree/api/v1/variants/variant"
end
