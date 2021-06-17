module Spree
  module Api
    module V2
      module Platform
        class VariantSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          attributes :name, :width, :options_text, :option_values

          attribute :stock_items do |variant|
            variant.stock_items
          end

          attribute :stock_locations do |variant|
            variant.stock_locations
          end

          attribute :in_stock do |variant|
            variant.in_stock?
          end

          attribute :purchasable do |variant|
            variant.purchasable?
          end

          belongs_to :product
          has_many :images
          has_many :option_values
          has_many :stock_locations
          has_many :stock_items
        end
      end
    end
  end
end
