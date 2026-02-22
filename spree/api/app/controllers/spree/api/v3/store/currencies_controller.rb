module Spree
  module Api
    module V3
      module Store
        class CurrenciesController < Store::BaseController
          # GET /api/v3/store/currencies
          def index
            currencies = current_store.supported_currencies_list

            render json: {
              data: currencies.map { |currency| Spree.api.currency_serializer.new(currency).to_h }
            }
          end
        end
      end
    end
  end
end
