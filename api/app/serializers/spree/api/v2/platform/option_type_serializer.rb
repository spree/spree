module Spree
  module Api
    module V2
      module Platform
        class OptionTypeSerializer < BaseSerializer
          include ::Spree::Api::V2::ResourceSerializerConcern

          has_many :option_values
        end
      end
    end
  end
end
