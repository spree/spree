# frozen_string_literal: true

module Spree
  module Events
    class ProductSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          name: resource.name,
          slug: resource.slug,
          status: resource.status.to_s,
          tax_category_id: association_prefix_id(:tax_category),
          shipping_category_id: association_prefix_id(:shipping_category),
          available_on: timestamp(resource.available_on),
          discontinue_on: timestamp(resource.discontinue_on),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
