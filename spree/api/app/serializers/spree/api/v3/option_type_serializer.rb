module Spree
  module Api
    module V3
      class OptionTypeSerializer < BaseSerializer
        typelize name: :string, label: :string, position: :number, kind: [:string, enum: Spree::OptionType::KINDS]

        attributes :name, :label, :position, :kind
      end
    end
  end
end
