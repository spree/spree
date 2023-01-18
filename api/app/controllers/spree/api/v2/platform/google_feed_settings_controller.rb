module Spree
  module Api
    module V2
      module Platform
        class GoogleFeedSettingsController < ResourceController
          private

          def model_class
            Spree::GoogleFeedSetting
          end
        end
      end
    end
  end
end
