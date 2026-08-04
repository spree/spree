# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # A fulfilled unit. Admin-only: it exists so the dashboard can offer
        # what is actually returnable or exchangeable — a return is against a
        # shipped unit, not against a line item.
        class FulfillmentItemSerializer < BaseSerializer
          typelize quantity: :number,
                   status: :string,
                   variant_id: [:string, nullable: true],
                   line_item_id: [:string, nullable: true],
                   name: [:string, nullable: true],
                   options_text: [:string, nullable: true]

          attributes :quantity, :status

          attribute :variant_id do |item|
            item.variant&.prefixed_id
          end

          attribute :line_item_id do |item|
            item.line_item&.prefixed_id
          end

          attribute :name do |item|
            item.variant&.product&.name
          end

          attribute :options_text do |item|
            item.variant&.options_text
          end
        end
      end
    end
  end
end
