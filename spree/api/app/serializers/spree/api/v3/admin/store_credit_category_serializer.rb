module Spree
  module Api
    module V3
      module Admin
        class StoreCreditCategorySerializer < V3::BaseSerializer
          typelize name: :string,
                   non_expiring: :boolean

          attributes :name,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :non_expiring do |store_credit_category|
            store_credit_category.non_expiring?
          end
        end
      end
    end
  end
end
