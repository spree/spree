module Spree
  module Api
    module V2
      module Platform
        class OrderSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern
          set_type :order

          attributes :number, :item_total, :total, :ship_total, :adjustment_total, :created_at,
                     :updated_at, :completed_at, :included_tax_total, :additional_tax_total, :display_additional_tax_total,
                     :display_included_tax_total, :tax_total, :currency, :state, :token, :email,
                     :display_item_total, :display_ship_total, :display_adjustment_total, :display_tax_total,
                     :promo_total, :display_promo_total, :item_count, :special_instructions, :display_total,
                     :pre_tax_item_amount, :display_pre_tax_item_amount, :pre_tax_total, :display_pre_tax_total,
                     :shipment_state, :payment_state

          has_many :line_items
        end
      end
    end
  end
end
