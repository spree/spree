object @line_item
attributes *line_item_attributes
node(:display_single_amount) { |li| li.single_display_amount.to_s }
node(:display_total_amount) { |li| li.display_amount.to_s }
child :variant do
  extends "spree/api/variants/variant"
  attributes :product_id
  child(:images => :images) { extends "spree/api/images/show" }
end
