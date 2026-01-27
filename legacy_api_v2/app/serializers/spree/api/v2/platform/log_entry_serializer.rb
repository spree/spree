module Spree
  module Api
    module V2
      module Platform
        class LogEntrySerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :source, polymorphic: true
        end
      end
    end
  end
end
