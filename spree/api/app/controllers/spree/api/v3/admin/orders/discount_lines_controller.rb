module Spree
  module Api
    module V3
      module Admin
        module Orders
          class DiscountLinesController < BaseController
            protected

            def model_class
              Spree::DiscountLine
            end

            def serializer_class
              Spree.api.admin_discount_line_serializer
            end

            def parent_association
              :discount_lines
            end
          end
        end
      end
    end
  end
end
