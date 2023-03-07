module Spree
  module Api
    module V2
      module Platform
        class DataFeedSettingsController < ResourceController
          private

          def model_class
            Spree::DataFeedSetting
          end
        end
      end
    end
  end
end
