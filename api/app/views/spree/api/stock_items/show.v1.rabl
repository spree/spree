object @stock_item
attributes *stock_item_attributes
child(:variant) do
  extends "spree/api/variants/small"
end
