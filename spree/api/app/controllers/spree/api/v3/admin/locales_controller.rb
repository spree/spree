module Spree
  module Api
    module V3
      module Admin
        # Lists the locales a merchant can translate content into for the
        # current store (its supported_locales_list), so the dashboard's locale
        # switcher enumerates locales instead of hardcoding them.
        class LocalesController < Admin::BaseController
          scoped_resource :settings

          # GET /api/v3/admin/locales
          def index
            params_for_serializer = { default_locale: current_store.default_locale }

            render json: {
              data: current_store.supported_locales_list.map do |code|
                Spree.api.locale_serializer.new(
                  OpenStruct.new(code: code, name: locale_name(code)),
                  params: params_for_serializer
                ).to_h
              end
            }
          end

          private

          def action_kind
            'read'
          end

          def locale_name(code)
            I18n.t('spree.i18n.this_file_language', locale: code, default: code)
          end
        end
      end
    end
  end
end
