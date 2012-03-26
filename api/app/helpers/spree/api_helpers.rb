module Spree
  module Api
    module ApiHelpers
      def required_fields_for(model)
        required_fields = model._validators.select do |field, validations|
          validations.any? { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) }
        end.keys
        # Permalinks presence is validated, but are really automatically generated
        # Therefore we shouldn't tell API clients that they MUST send one through
        required_fields.delete(:permalink)
        required_fields
      end

      def product_attributes
        [:id, :name, :description, :price,
         :available_on, :permalink, :count_on_hand]
      end
    end
  end
end
