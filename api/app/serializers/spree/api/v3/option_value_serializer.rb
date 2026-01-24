module Spree
  module Api
    module V3
      class OptionValueSerializer < BaseSerializer
        typelize_from Spree::OptionValue
        typelize option_type_name: :string, option_type_presentation: :string

        attributes :id, :name, :presentation, :position, :option_type_id

        attribute :option_type_name do |option_value|
          option_value.option_type.name
        end

        attribute :option_type_presentation do |option_value|
          option_value.option_type.presentation
        end
      end
    end
  end
end
