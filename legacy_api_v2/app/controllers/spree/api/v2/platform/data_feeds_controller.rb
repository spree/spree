module Spree
  module Api
    module V2
      module Platform
        class DataFeedsController < ResourceController
          private

          def model_class
            Spree::DataFeed
          end

          def resource_serializer
            Spree.api.platform_data_feed_serializer
          end
        end
      end
    end
  end
end
