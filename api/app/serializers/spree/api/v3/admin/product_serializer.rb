module Spree
  module Api
    module V3
      module Admin
        # Admin API Product Serializer
        # Full product data including admin-only fields
        # Extends the store serializer with additional attributes
        class ProductSerializer < V3::ProductSerializer

          # Additional type hints for admin-only computed attributes
          typelize status: :string, make_active_at: 'string | null', discontinue_on: 'string | null',
                   cost_price: 'number | null', cost_currency: 'string | null',
                   deleted_at: 'string | null'

          # Admin-only attributes
          attributes :status, :make_active_at, :discontinue_on, deleted_at: :iso8601

          attribute :cost_price do |product|
            product.master&.cost_price&.to_f
          end

          attribute :cost_currency do |product|
            product.master&.cost_currency
          end

          # Admin uses admin variant serializer
          many :variants,
               resource: Spree::Api::V3::Admin::VariantSerializer,
               if: proc { params[:includes]&.include?('variants') }

          one :default_variant,
              resource: Spree::Api::V3::Admin::VariantSerializer,
              if: proc { params[:includes]&.include?('default_variant') }

          one :master,
              key: :master_variant,
              resource: Spree::Api::V3::Admin::VariantSerializer,
              if: proc { params[:includes]&.include?('master_variant') }
        end
      end
    end
  end
end
