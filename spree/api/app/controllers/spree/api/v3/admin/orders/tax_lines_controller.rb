module Spree
  module Api
    module V3
      module Admin
        module Orders
          class TaxLinesController < BaseController
            protected

            def model_class
              Spree::TaxLine
            end

            def serializer_class
              Spree.api.admin_tax_line_serializer
            end

            def parent_association
              :tax_lines
            end
          end
        end
      end
    end
  end
end
