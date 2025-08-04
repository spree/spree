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
            Spree::Api::Dependencies.platform_data_feed_serializer.constantize
          end
        end
      end
    end
  end
end
