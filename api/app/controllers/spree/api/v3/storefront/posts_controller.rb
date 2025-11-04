module Spree
  module Api
    module V3
      module Storefront
        class PostsController < ResourceController
          # Public endpoint - no authentication required

          protected

          def scope
            Spree::Post.published.for_store(current_store).accessible_by(current_ability, :show)
          end

          def model_class
            Spree::Post
          end

          def serializer_class
            # Simple inline serializer for posts
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
                  published_at: resource.published_at,
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
