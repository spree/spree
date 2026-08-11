module Spree
  module Api
    module V3
      module Admin
        # Lists the locales a merchant can translate content into for the
        # current store (its supported_locales_list), so the dashboard's locale
        # switcher enumerates locales instead of hardcoding them.
        class LocalesController < Admin::BaseController
          # Reference data the dashboard shell needs regardless of the caller's
          # grant — exempt from the key gate like `/tags` and `/countries`.
          skip_scope_check!

          # GET /api/v3/admin/locales
          def index
            render json: {
              data: current_store.supported_locales.map do |locale|
                Spree.api.locale_serializer.new(locale).to_h
              end
            }
          end

          private

          def action_kind
            'read'
          end
        end
      end
    end
  end
end
