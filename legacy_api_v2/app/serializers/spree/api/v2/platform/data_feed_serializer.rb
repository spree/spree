module Spree
  module Api
    module V2
      module Platform
        class DataFeedSerializer < BaseSerializer
          set_type :data_feed

          attributes :name, :type, :slug, :active
        end
      end
    end
  end
end
