module Spree
  module Api
    module V3
      class TaxonomySerializer < BaseSerializer
        def attributes
          base_attrs = {
            id: resource.id,
            name: resource.name,
          }

          base_attrs[:root] = serialize_root if include?('root')
          base_attrs[:taxons] = serialize_taxons if include?('taxons')

          base_attrs
        end

        private

        def serialize_root
          root_serializer.new(resource.root, nested_context('root')).as_json
        end

        def root_serializer
          Spree::Api::Dependencies.v3_storefront_taxon_serializer.constantize
        end

        def serialize_taxons
          taxons_serializer.new(resource.taxons, nested_context('taxons')).as_json
        end

        def taxons_serializer
          Spree::Api::Dependencies.v3_storefront_taxon_serializer.constantize
        end
      end
    end
  end
end
