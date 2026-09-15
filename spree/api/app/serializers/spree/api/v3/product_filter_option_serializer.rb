module Spree
  module Api
    module V3
      class ProductFilterOptionSerializer < BaseSerializer
        typelize id: :string,
                 type: "'option'",
                 name: :string,
                 label: :string,
                 kind: [:string, enum: Spree::OptionType::KINDS],
                 options: [:ProductFilterOptionValue, multi: true]

        attributes :id, :type, :name, :label, :kind

        many :options, resource: proc { Spree.api.product_filter_option_value_serializer }
      end
    end
  end
end
