object @variant
attributes *variant_attributes

cache ['big_variant', root_object]

node(:display_price) { |p| p.display_price.to_s }
node(:options_text) { |v| v.options_text }
node(:in_stock) { |v| v.in_stock? }

child :option_values => :option_values do
  attributes *option_value_attributes
end

child(:images => :images) do
  attributes *image_attributes
  code(:urls) do |v|
    v.attachment.styles.keys.inject({}) { |urls, style| urls[style] = v.attachment.url(style); urls  }
  end
end

child(:stock_items => :stock_items) do
  attributes :id, :count_on_hand, :stock_location_id, :backorderable
  attribute :available? => :available

  glue(:stock_location) do
    attribute :name => :stock_location_name
  end
end
