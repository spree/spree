module Spree
  class OrderSerializer < ActiveModel::Serializer
    attributes :id, :number, :item_total, :total, :ship_total,
               :state, :adjustment_total, :user_id, :created_at,
               :updated_at, :completed_at, :payment_total,
               :shipment_state, :payment_state, :email, :special_instructions,
               :channel, :included_tax_total, :additional_tax_total,
               :display_included_tax_total, :display_additional_tax_total

    has_many :line_items
    has_many :payments
    has_many :adjustments
    has_many :shipments

    has_one :bill_address, serializer: Spree::AddressSerializer
    has_one :ship_address, serializer: Spree::AddressSerializer
  end
end
