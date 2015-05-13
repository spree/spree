object @variant

cache [I18n.locale, @current_user_roles.include?('admin'), 'big_variant', root_object]

extends "spree/api/v1/variants/small"

child(:stock_items => :stock_items) do
  attributes :id, :count_on_hand, :stock_location_id, :backorderable
  attribute :available? => :available

  glue(:stock_location) do
    attribute :name => :stock_location_name
  end
end
