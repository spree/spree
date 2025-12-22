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

          def resource_serializer
            Spree.api.platform_store_credit_serializer
          end
        end
      end
    end
  end
end
