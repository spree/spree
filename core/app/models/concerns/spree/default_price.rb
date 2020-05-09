module Spree
  module DefaultPrice
    extend ActiveSupport::Concern

    included do
      has_one :default_price,
              -> { where currency: Spree::Config[:currency] },
              class_name: 'Spree::Price',
              dependent: :destroy

      delegate :display_price, :display_amount, :price, :currency, :price=,
               :price_including_vat_for, :currency=, :display_compare_at_price,
               :compare_at_price, :compare_at_price=, to: :find_or_build_default_price

      after_save :save_default_price

      def default_price
        Spree::Price.unscoped { super }
      end

      def has_default_price?
        !default_price.nil?
      end

      def find_or_build_default_price
        default_price || build_default_price
      end

      private

      def default_price_changed?
        default_price && (default_price.changed? || default_price.new_record?)
      end

      def save_default_price
        default_price.save if default_price_changed?
      end
    end
  end
end
