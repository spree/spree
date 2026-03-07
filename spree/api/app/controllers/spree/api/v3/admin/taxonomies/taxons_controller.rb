module Spree
  module Api
    module V3
      module Admin
        module Taxonomies
          class TaxonsController < ResourceController
            protected

            def model_class
              Spree::Taxon
            end

            def serializer_class
              Spree.api.admin_taxon_serializer
            end

            def set_parent
              @parent = current_store.taxonomies.find_by_prefix_id!(params[:taxonomy_id])
              authorize!(:show, @parent)
            end

            def parent_association
              :taxons
            end
          end
        end
      end
    end
  end
end
