module Spree
  module Api
    module V3
      class OptionValueSerializer < BaseSerializer
        typelize name: :string, label: :string, position: :number, option_type_id: :string,
                 option_type_name: :string, option_type_label: :string,
                 color_code: 'string | null', image_url: 'string | null'

        attribute :option_type_id do |option_value|
          option_value.option_type&.prefixed_id
        end

        attributes :name, :label, :position, :color_code

        attribute :option_type_name do |option_value|
          option_value.option_type.name
        end

        attribute :option_type_label do |option_value|
          option_value.option_type.label
        end

        attribute :image_url do |option_value|
          image_url_for(option_value.image)
        end
      end
    end
  end
end
