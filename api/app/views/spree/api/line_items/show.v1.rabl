object @line_item
attributes *line_item_attributes
child :variant do
  extends "spree/api/variants/variant"
  attributes :product_id
  child(:images => :images) { extends "spree/api/images/show" }
end
