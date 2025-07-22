module Spree
  module Api
    module V2
      module Platform
        class DataFeedsController < ResourceController
          private

          def model_class
            Spree::DataFeed
          end
        end
      end
    end
  end
end
