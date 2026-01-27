module Spree
  module V2
    module Storefront
      class StoreCreditCategorySerializer < BaseSerializer
        set_type :store_credit_category

        attributes :name
      end
    end
  end
end
