module Spree
  module Api
    module V3
      class OptionValueSerializer < BaseSerializer
        typelize name: :string, presentation: :string, position: :number, option_type_id: :string,
                 option_type_name: :string, option_type_presentation: :string

        attribute :option_type_id do |option_value|
          option_value.option_type&.prefixed_id
        end

        attributes :name, :presentation, :position

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
