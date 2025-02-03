module Spree
  module ReportLineItems
    class ProductsPerformance < Spree::ReportLineItem
      include Spree::BaseHelper

      attribute :sku, :string
      attribute :name, :string
      attribute :url, :string
      attribute :vendor, :string
      attribute :brand, :string
      attribute :category_lvl0, :string
      attribute :category_lvl1, :string
      attribute :category_lvl2, :string
      attribute :price, :string
      attribute :weeks_online, :integer
      attribute :discount, :string
      attribute :tax, :string
      attribute :quantity, :integer
      attribute :total_sales, :string
      attribute :total, :string

      # needed to generate the url
      alias current_store store

      delegate :sku, :name, to: :record

      def url
        spree_storefront_resource_url(record)
      end

      def vendor
        record.vendor_name
      end

      def brand
        record.brand_name
      end

      def category_lvl0
        mapped_categories[0]
      end

      def category_lvl1
        mapped_categories[1]
      end

      def category_lvl2
        mapped_categories[2]
      end

      def price
        record.price_in(currency).display_amount
      end

      def total
        Spree::Money.new(record.total, currency: currency)
      end

      def discount
        Spree::Money.new(record.discount_total, currency: currency)
      end

      def tax
        Spree::Money.new(record.tax, currency: currency)
      end

      def quantity
        record.sales_count
      end

      def total_sales
        Spree::Money.new(record.sales_total, currency: currency)
      end

      def weeks_online
        (Time.current - record.activated_at.in_time_zone(store.preferred_timezone)).seconds.in_weeks.to_i
      end

      def mapped_categories
        @mapped_categories ||= record.main_taxon&.pretty_name&.split('->')&.map(&:strip)
      end
    end
  end
end
