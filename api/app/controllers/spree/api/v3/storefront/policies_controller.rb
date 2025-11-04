module Spree
  module Api
    module V3
      module Storefront
        class PoliciesController < ResourceController
          # Public endpoint - no authentication required

          protected

          def scope
            Spree::Policy.active.for_store(current_store).accessible_by(current_ability, :show)
          end

          def model_class
            Spree::Policy
          end

          def serializer_class
            # Simple inline serializer for policies
            Class.new do
              attr_reader :resource

              def initialize(resource, context = {})
                @resource = resource
              end

              def as_json
                {
                  id: resource.id,
                  title: resource.title,
                  slug: resource.slug,
                  content: resource.content,
                  created_at: resource.created_at,
                  updated_at: resource.updated_at
                }
              end
            end
          end

          # Not needed for index/show
          def permitted_params
            {}
          end
        end
      end
    end
  end
end
