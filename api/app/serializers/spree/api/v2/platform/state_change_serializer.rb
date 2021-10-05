module Spree
  module Api
    module V2
      module Platform
        class StateChangeSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :user
        end
      end
    end
  end
end
