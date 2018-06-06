module Spree
  module Api
    module V2
      module Storefront
        class TaxonomiesController < ::Spree::Api::V2::BaseController
          def index
            render json: serialize(collection), status: 200
          end

          def show
            render json: serialize(resource), status: 200
          end

          private

          def collection
            options = params.merge(ability_options).merge(
              order: :name
            )

            paginate(
              dependencies[:finder].new(options).call
            )
          end

          def resource
            dependencies[:finder].new(ability_options).call.find(params[:id])
          end

          def dependencies
            {
              finder:     Spree::Taxonomies::Find,
              serializer: Spree::V2::Storefront::TaxonomySerializer
            }
          end

          def serialize(object)
            options = {
              include: [:root, :'root.children']
            }

            dependencies[:serializer].new(object, options).serializable_hash
          end

          def ability_options
            {
              ability: current_ability,
              action:  :read
            }
          end
        end
      end
    end
  end
end
