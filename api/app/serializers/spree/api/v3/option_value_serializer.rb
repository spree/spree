module Spree
  module Api
    module V3
      class OptionValueSerializer < BaseSerializer
        attributes :id, :name, :presentation, :position, :option_type_id

        attribute :option_type_name do |option_value|
          option_value.option_type.name
        end
      end
    end
  end
end
