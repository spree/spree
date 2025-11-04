module Spree
  module Api
    module V3
      module Storefront
        class PagesController < ResourceController
          # Public endpoint - no authentication required

          protected

          def scope
            Spree::CmsPage.visible.for_store(current_store).accessible_by(current_ability, :show)
          end

          def model_class
            Spree::CmsPage
          end

          def serializer_class
            # Simple inline serializer for pages
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
                  meta_title: resource.meta_title,
                  meta_description: resource.meta_description,
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
