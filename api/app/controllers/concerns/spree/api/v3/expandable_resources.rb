module Spree
  module Api
    module V3
      # Provides support for expanding nested resources in serializers
      # Similar to Stripe's expand parameter: https://docs.stripe.com/api/expanding_objects
      #
      # Usage:
      #   GET /api/v3/storefront/products/1?include=variants,images,taxons
      #   GET /api/v3/storefront/products/1?include=variants.images,variants.option_values
      module ExpandableResources
        extend ActiveSupport::Concern

        protected

        # Returns list of associations to include based on query params
        # @return [Array<String>] List of associations to expand
        def requested_includes
          return [] unless params[:include].present?

          # Split by comma, remove whitespace
          params[:include].to_s.split(',').map(&:strip).reject(&:blank?)
        end

        # Check if a specific association should be included
        # @param association [String, Symbol] The association name
        # @return [Boolean]
        def include?(association)
          requested_includes.include?(association.to_s)
        end

        # Get nested includes for an association
        # For example, if params[:include] = 'variants.images,variants.option_values'
        # Then nested_includes_for('variants') returns ['images', 'option_values']
        #
        # @param parent [String, Symbol] The parent association
        # @return [Array<String>]
        def nested_includes_for(parent)
          prefix = "#{parent}."
          requested_includes
            .select { |inc| inc.start_with?(prefix) }
            .map { |inc| inc.sub(prefix, '') }
        end
      end
    end
  end
end
