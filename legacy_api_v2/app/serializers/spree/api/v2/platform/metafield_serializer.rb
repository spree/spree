module Spree
  module Api
    module V2
      module Platform
        class MetafieldSerializer < BaseSerializer
          set_type :metafield

          attributes :name, :type, :display_on

          attribute :key do |metafield|
            metafield.full_key
          end

          attribute :value do |metafield|
            metafield.serialize_value
          end
        end
      end
    end
  end
end
