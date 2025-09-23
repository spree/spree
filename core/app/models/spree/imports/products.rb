module Spree
  module Imports
    class Products < Spree::Import
      CSV_HEADERS = [
        'product_id',
        'sku',
        'name',
        'slug',
        'status',
        'vendor_name',
        'brand_name',
        'description',
        'meta_title',
        'meta_description',
        'meta_keywords',
        'tags',
        'labels',
        'price',
        'compare_at_price',
        'currency',
        'width',
        'height',
        'depth',
        'dimensions_unit',
        'weight',
        'weight_unit',
        'available_on',
        'discontinue_on',
        'track_inventory',
        'inventory_count',
        'inventory_backorderable',
        'tax_category',
        'digital',
        'image1_src',
        'image2_src',
        'image3_src',
        'option1_name',
        'option1_value',
        'option2_name',
        'option2_value',
        'option3_name',
        'option3_value',
        'category1',
        'category2',
        'category3',
      ].freeze

      def multi_line_csv?
        true
      end

      def handle_csv_line(record)

      end
    end
  end
end
