module Spree
  module Api
    module V2
      module Platform
        class OptionValueSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :option_type
        end
      end
    end
  end
end
