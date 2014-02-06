object @variant
cache ['variant_full', root_object]
extends "spree/api/variants/variant"

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
