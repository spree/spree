module Spree
  module Api
    module ApiHelpers
      def required_fields_for(model)
        @product._validators.select do |field, validations|
          validations.any? { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) }
        end
      end
    end
  end
end
