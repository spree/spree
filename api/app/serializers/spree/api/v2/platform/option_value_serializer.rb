module Spree
  module Api
    module V2
      module Platform
        class OptionValueSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :option_type, serializer: Spree.api.platform_option_type_serializer
        end
      end
    end
  end
end
