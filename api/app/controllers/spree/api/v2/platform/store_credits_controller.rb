module Spree
  module Api
    module V2
      module Platform
        class StoreCreditsController < ResourceController
          private

          def model_class
            Spree::StoreCredit
          end

          def scope_includes
            [:user, :created_by, :category, :credit_type]
          end
        end
      end
    end
  end
end
