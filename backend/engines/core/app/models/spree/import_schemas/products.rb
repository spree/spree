module Spree
  module ImportSchemas
    class Products < Spree::ImportSchema
      FIELDS = [
        { name: 'slug', label: 'Slug', required: true },
        { name: 'sku', label: 'SKU', required: true },
        { name: 'name', label: 'Name', required: true },
        { name: 'price', label: 'Price', required: true },
        { name: 'status', label: 'Status' },
        { name: 'description', label: 'Description' },
        { name: 'meta_title', label: 'Meta Title' },
        { name: 'meta_description', label: 'Meta Description' },
        { name: 'meta_keywords', label: 'Meta Keywords' },
        { name: 'tags', label: 'Tags' },
        { name: 'compare_at_price', label: 'Compare at Price' },
        { name: 'currency', label: 'Currency' },
        { name: 'width', label: 'Width' },
        { name: 'height', label: 'Height' },
        { name: 'depth', label: 'Depth' },
        { name: 'dimensions_unit', label: 'Dimensions Unit' },
        { name: 'weight', label: 'Weight' },
        { name: 'weight_unit', label: 'Weight Unit' },
        { name: 'available_on', label: 'Available On' },
        { name: 'discontinue_on', label: 'Discontinue On' },
        { name: 'track_inventory', label: 'Track Inventory' },
        { name: 'inventory_count', label: 'Inventory Count' },
        { name: 'inventory_backorderable', label: 'Inventory Backorderable' },
        { name: 'tax_category', label: 'Tax Category' },
        { name: 'shipping_category', label: 'Shipping Category' },
        { name: 'image1_src', label: 'Image 1 URL' },
        { name: 'image2_src', label: 'Image 2 URL' },
        { name: 'image3_src', label: 'Image 3 URL' },
        { name: 'option1_name', label: 'Option 1 Name' },
        { name: 'option1_value', label: 'Option 1 Value' },
        { name: 'option2_name', label: 'Option 2 Name' },
        { name: 'option2_value', label: 'Option 2 Value' },
        { name: 'option3_name', label: 'Option 3 Name' },
        { name: 'option3_value', label: 'Option 3 Value' },
        { name: 'category1', label: 'Category 1' },
        { name: 'category2', label: 'Category 2' },
        { name: 'category3', label: 'Category 3' }
      ].freeze
    end
  end
end
