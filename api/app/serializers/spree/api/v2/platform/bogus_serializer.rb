module Spree
  module Api
    module V2
      module Platform
        # module Gateway
          class BogusSerializer < BaseSerializer
            include ResourceSerializerConcern
          end
        # end
      end
    end
  end
end
