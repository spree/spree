module Spree
  module ReportLineItems
    class ProductsPerformance < Spree::ReportLineItem
      attribute :sku, :string
      attribute :name, :string
      attribute :vendor, :string
      attribute :brand, :string
      attribute :category_lvl0, :string
      attribute :category_lvl1, :string
      attribute :category_lvl2, :string
      attribute :price, :string
      attribute :weeks_online, :integer
      attribute :pre_tax_amount, :string
      attribute :tax_total, :string
      attribute :quantity, :integer
      attribute :promo_total, :string
      attribute :total, :string

      delegate :sku, :name, to: :record

      def vendor
        record.try(:vendor_name)
      end

      def brand
        record.try(:brand_name)
      end

      def category_lvl0
        mapped_categories&.first
      end

      def category_lvl1
        mapped_categories&.second
      end

      def category_lvl2
        mapped_categories&.third
      end

      def price
        record.price_in(currency).display_amount
      end

      def pre_tax_amount
        Spree::Money.new(record.pre_tax_amount, currency: currency)
      end

      def promo_total
        Spree::Money.new(record.promo_total, currency: currency)
      end

      def tax_total
        Spree::Money.new(record.tax_total, currency: currency)
      end

      def quantity
        record.quantity
      end

      def total
        Spree::Money.new(record.total, currency: currency)
      end

      def weeks_online
        start_date = record.available_on.presence || record.created_at

        (Time.current - start_date.in_time_zone(store.preferred_timezone)).seconds.in_weeks.to_i
      end

      def mapped_categories
        @mapped_categories ||= record.main_taxon&.pretty_name&.split('->')&.map(&:strip)
      end
    end
  end
end
