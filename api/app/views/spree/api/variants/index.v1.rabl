object false
node(:count) { @variants.count }
node(:total_count) { @variants.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:pages) { @variants.num_pages }

child(@variants => :variants) do
  attributes *variant_attributes
  child(:option_values => :option_values) { attributes *option_value_attributes }
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
end
