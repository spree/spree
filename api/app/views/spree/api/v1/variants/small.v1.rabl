cache [I18n.locale, @current_user_roles.include?('admin'), 'small_variant', root_object]

attributes *variant_attributes

node(:display_price) { |p| p.display_price.to_s }
node(:options_text) { |v| v.options_text }
node(:track_inventory) { |v| v.should_track_inventory? }
node(:in_stock) { |v| v.in_stock? }
node(:is_backorderable) { |v| v.is_backorderable? }
node(:total_on_hand) { |v| v.total_on_hand }
node(:is_destroyed) { |v| v.destroyed? }

child :option_values => :option_values do
  attributes *option_value_attributes
end

child(:images => :images) { extends "spree/api/v1/images/show" }
