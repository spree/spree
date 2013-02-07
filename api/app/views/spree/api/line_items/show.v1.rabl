object @line_item
attributes *line_item_attributes
child :variant do
  extends "spree/api/variants/variant"
  child(:images => :images) { extends "spree/api/images/show" }
end
