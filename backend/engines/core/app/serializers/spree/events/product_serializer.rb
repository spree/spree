# frozen_string_literal: true

module Spree
  module Events
    class ProductSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          name: resource.name,
          slug: resource.slug,
          status: resource.status.to_s,
          tax_category_id: public_id(resource.tax_category),
          shipping_category_id: public_id(resource.shipping_category),
          available_on: timestamp(resource.available_on),
          discontinue_on: timestamp(resource.discontinue_on),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
