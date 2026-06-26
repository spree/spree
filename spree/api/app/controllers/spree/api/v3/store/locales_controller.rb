module Spree
  module Api
    module V3
      module Store
        class LocalesController < Store::BaseController
          include Spree::Api::V3::HttpCaching

          # GET /api/v3/store/locales
          def index
            locales = current_store.supported_locales

            return unless cache_collection(locales)

            render json: {
              data: locales.map { |locale| Spree.api.locale_serializer.new(locale).to_h }
            }
          end
        end
      end
    end
  end
end
