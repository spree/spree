object @stock_movement
attributes *stock_movement_attributes
child :stock_item do
  extends 'spree/api/v1/stock_items/show'
end
