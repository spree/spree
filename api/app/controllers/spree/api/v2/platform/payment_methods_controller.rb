module Spree
  module Api
    module V2
      module Platform
        class PaymentMethodsController < ResourceController
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

            super + preferred_attributes
          end
        end
      end
    end
  end
end
