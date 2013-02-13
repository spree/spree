object @line_item
attributes *line_item_attributes
child :variant do
  extends "spree/api/variants/variant"
  child(:product) { attributes :id, :description }
  child(:images => :images) { extends "spree/api/images/show" }
end
