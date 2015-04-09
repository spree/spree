module Spree
  class OrderSerializer < ActiveModel::Serializer
    attributes :id, :number, :item_total, :total, :ship_total,
               :state, :adjustment_total, :user_id, :created_at,
               :updated_at, :completed_at, :payment_total,
               :shipment_state, :payment_state, :email, :special_instructions,
               :channel, :included_tax_total, :additional_tax_total,
               :display_included_tax_total, :display_additional_tax_total,
               :display_total, :total_quantity, :display_item_total,
               :checkout_steps, :guest_token, :display_ship_total, :currency

    has_many :line_items
    has_many :payments
    has_many :adjustments
    has_many :shipments
    has_many :credit_cards

    has_one :bill_address
    has_one :ship_address

    def total_quantity
      object.line_items.sum(:quantity)
    end

    def checkout_steps
      object.checkout_steps
    end

    def token
      object.token
    end
  end
end
