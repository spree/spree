module Spree
  module Api
    module V2
      module Platform
        class OptionTypeSerializer < BaseSerializer
          include ResourceSerializerConcern

          has_many :option_values, serializer: Spree::Api::Dependencies.platform_option_value_serializer.constantize
        end
      end
    end
  end
end
