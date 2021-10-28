module Spree
  module Api
    module V2
      module Platform
        class PaymentMethodsController < ResourceController
          include ::Spree::Api::V2::Platform::ActsAsListReposition

          private

          def model_class
            Spree::PaymentMethod
          end

          def spree_permitted_attributes
            preferred_attributes = []

            if action_name == 'update'
              resource.defined_preferences.each do |preference|
                preferred_attributes << "preferred_#{preference}".to_sym
              end
            end

            Spree::PaymentMethod.json_api_permitted_attributes + [
              { store_ids: [] }
            ] + preferred_attributes
          end
        end
      end
    end
  end
end
