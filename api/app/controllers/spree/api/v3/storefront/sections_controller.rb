module Spree
  module Api
    module V3
      module Storefront
        class SectionsController < BaseController
          before_action :set_page

          # GET /api/v3/storefront/pages/:page_id/sections
          def index
            @sections = @page.sections.ordered

            render json: {
              data: serialize_collection(@sections)
            }
          end

          # GET /api/v3/storefront/pages/:page_id/sections/:id
          def show
            @section = @page.sections.find(params[:id])
            render json: serialize_resource(@section)
          end

          protected

          def set_page
            @page = Spree::Page.visible.for_store(current_store).find(params[:page_id])
          end

          def serialize_collection(collection)
            collection.map { |item| serializer_class.new(item, serializer_context).as_json }
          end

          def serialize_resource(resource)
            serializer_class.new(resource, serializer_context).as_json
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_section_serializer.constantize
          end

          def serializer_context
            {
              store: current_store,
              locale: current_locale,
              includes: requested_includes
            }
          end
        end
      end
    end
  end
end
