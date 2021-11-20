module Spree
  module Api
    module V2
      module Platform
        class TaxonsController < ResourceController
          include ::Spree::Api::V2::Platform::NestedSetRepositionConcern

          private

          def successful_reposition_actions
            reload_taxon_and_set_new_permalink(resource)
            update_permalinks_on_child_taxons

            render_serialized_payload { serialize_resource(resource) }
          end

          def reload_taxon_and_set_new_permalink(taxon)
            taxon.reload
            taxon.set_permalink
            taxon.save!
          end

          def update_permalinks_on_child_taxons
            resource.descendants.each do |taxon|
              reload_taxon_and_set_new_permalink(taxon)
            end
          end

          def model_class
            Spree::Taxon
          end

          def scope_includes
            node_includes = %i[icon parent taxonomy]

            {
              parent: node_includes,
              children: node_includes,
              taxonomy: [root: node_includes],
              icon: [attachment_attachment: :blob]
            }
          end

          def serializer_params
            super.merge(include_products: action_name == 'show')
          end

          def spree_permitted_attributes
            super + [:new_parent_id, :new_position_idx]
          end
        end
      end
    end
  end
end
