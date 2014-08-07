object @variant
attributes *variant_attributes

cache [I18n.locale, 'big_variant', root_object]

extends "spree/api/variants/small"

node :total_on_hand do
  root_object.total_on_hand
end


child(:stock_items => :stock_items) do
  attributes :id, :count_on_hand, :stock_location_id, :backorderable
  attribute :available? => :available

  glue(:stock_location) do
    attribute :name => :stock_location_name
  end
end
