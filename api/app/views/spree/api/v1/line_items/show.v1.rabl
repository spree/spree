object @line_item
cache [I18n.locale, root_object]
attributes *line_item_attributes
node(:single_display_amount) { |li| li.single_display_amount.to_s }
node(:display_amount) { |li| li.display_amount.to_s }
node(:total) { |li| li.total }
child :variant do
  extends "spree/api/v1/variants/small"
  attributes :product_id
  child(:images => :images) { extends "spree/api/v1/images/show" }
end

child :adjustments => :adjustments do
  extends "spree/api/v1/adjustments/show"
end
