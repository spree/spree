module Spree
  module Api
    module V3
      module Admin
        class CustomFieldValidationsSerializer < V3::CustomFieldValidationsSerializer
          many :choices, resource: proc { Spree.api.admin_custom_field_choice_serializer }
        end
      end
    end
  end
end
