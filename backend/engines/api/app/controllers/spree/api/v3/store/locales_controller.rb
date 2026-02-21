module Spree
  module Api
    module V3
      module Store
        class LocalesController < Store::BaseController
          # GET /api/v3/store/locales
          def index
            locales = current_store.supported_locales_list

            render json: {
              data: locales.map { |code| Spree.api.locale_serializer.new(OpenStruct.new(code: code, name: locale_name(code))).to_h }
            }
          end

          private

          def locale_name(code)
            I18n.t('spree.i18n.this_file_language', locale: code, default: code)
          end
        end
      end
    end
  end
end
