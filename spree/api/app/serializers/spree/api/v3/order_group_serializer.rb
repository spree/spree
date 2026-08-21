module Spree
  module Api
    module V3
      # Store API Order Group Serializer
      #
      # What the customer bought in one checkout, when it was fulfilled by more
      # than one seller. They made one purchase and paid once, so this is what
      # their order history shows them — with the per-seller orders nested
      # inside it, each carrying its own items, delivery and tracking.
      class OrderGroupSerializer < BaseSerializer
        typelize number: :string, email: [:string, nullable: true], currency: :string,
                 total: [:string, nullable: true], display_total: [:string, nullable: true],
                 item_total: [:string, nullable: true], display_item_total: [:string, nullable: true],
                 fulfillment_status: [:string, nullable: true], payment_status: [:string, nullable: true],
                 completed_at: [:string, nullable: true],
                 billing_address: { nullable: true }, shipping_address: { nullable: true }

        attributes :number, :email, :currency

        attribute :total do |group|
          group.total.to_s
        end

        attribute :display_total do |group|
          group.display_total.to_s
        end

        attribute :item_total do |group|
          group.item_total.to_s
        end

        attribute :display_item_total do |group|
          group.display_item_total.to_s
        end

        # Rolled up across the children rather than stored, so it can never
        # disagree with the orders it describes.
        attribute :fulfillment_status do |group|
          group.fulfillment_status
        end

        attribute :payment_status do |group|
          group.payment_status
        end

        attribute :completed_at do |group|
          group.created_at
        end

        one :billing_address, resource: proc { Spree.api.address_serializer }
        one :shipping_address, resource: proc { Spree.api.address_serializer }

        # The whole point of the group: the customer sees one purchase, and the
        # seller orders inside it are how it will arrive.
        many :orders, resource: proc { Spree.api.order_serializer }
      end
    end
  end
end
