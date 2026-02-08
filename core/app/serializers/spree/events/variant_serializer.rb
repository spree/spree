# frozen_string_literal: true

module Spree
  module Events
    class VariantSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          sku: resource.sku,
          barcode: resource.barcode,
          is_master: resource.is_master,
          position: resource.position,
          weight: money(resource.weight),
          height: money(resource.height),
          width: money(resource.width),
          depth: money(resource.depth),
          weight_unit: resource.weight_unit,
          dimensions_unit: resource.dimensions_unit,
          cost_price: money(resource.cost_price),
          cost_currency: resource.cost_currency,
          track_inventory: resource.track_inventory,
          product_id: association_prefix_id(:product),
          tax_category_id: association_prefix_id(:tax_category),
          discontinue_on: timestamp(resource.discontinue_on),
          deleted_at: timestamp(resource.deleted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
