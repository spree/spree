module Spree
  module ImportSchemas
    class Products < Spree::ImportSchema
      FIELDS = [
        { name: 'product_id', required: true },
        { name: 'sku', required: true },
        { name: 'name', required: true },
        { name: 'price', required: true },
        { name: 'slug' },
        { name: 'status' },
        { name: 'description' },
        { name: 'meta_title' },
        { name: 'meta_description' },
        { name: 'meta_keywords' },
        { name: 'tags' },
        { name: 'compare_at_price' },
        { name: 'currency' },
        { name: 'width' },
        { name: 'height' },
        { name: 'depth' },
        { name: 'dimensions_unit' },
        { name: 'weight' },
        { name: 'weight_unit' },
        { name: 'available_on' },
        { name: 'discontinue_on' },
        { name: 'track_inventory' },
        { name: 'inventory_count' },
        { name: 'inventory_backorderable' },
        { name: 'tax_category' },
        { name: 'digital' },
        { name: 'image1_src' },
        { name: 'image2_src' },
        { name: 'image3_src' },
        { name: 'option1_name' },
        { name: 'option1_value' },
        { name: 'option2_name' },
        { name: 'option2_value' },
        { name: 'option3_name' },
        { name: 'option3_value' },
        { name: 'category1' },
        { name: 'category2' },
        { name: 'category3' }
      ].freeze
    end
  end
end
