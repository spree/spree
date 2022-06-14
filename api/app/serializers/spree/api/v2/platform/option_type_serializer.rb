module Spree
  module Api
    module V2
      module Platform
        class OptionTypeSerializer < BaseSerializer
          include ResourceSerializerConcern

          attributes :name

          has_many :option_values
        end
      end
    end
  end
end
