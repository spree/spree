module Spree
  module Api
    module V2
      module Platform
        class PaymentsController < ResourceController
          include NumberResource

          private

          def model_class
            Spree::Payment
          end
        end
      end
    end
  end
end
