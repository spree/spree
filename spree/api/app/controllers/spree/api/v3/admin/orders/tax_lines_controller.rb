module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Read-only: tax lines are written exclusively by the tax provider.
          class TaxLinesController < BaseController
            scoped_resource :orders

            protected

            def model_class
              Spree::TaxLine
            end

            def serializer_class
              Spree.api.admin_tax_line_serializer
            end

            def scope
              @parent.tax_lines
            end

            def collection_includes
              [:tax_rate, :line_item, :fulfillment, :fee]
            end
          end
        end
      end
    end
  end
end
