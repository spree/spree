# frozen_string_literal: true

module Spree
  module Events
    class ProductSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          name: resource.name,
          slug: resource.slug,
          status: resource.status.to_s,
          tax_category_id: resource.tax_category_id,
          shipping_category_id: resource.shipping_category_id,
          available_on: timestamp(resource.available_on),
          discontinue_on: timestamp(resource.discontinue_on),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
