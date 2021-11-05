module Spree
  module Api
    module V2
      module Platform
        class BaseSerializer < ::Spree::Api::V2::BaseSerializer
          attribute :webhook_metadata, if: proc { |_record, params|
            params[:webhook_metadata].present? && params[:webhook_metadata] == true
          } do |_object, params|
            {
              event: params[:event]
            }
          end
        end
      end
    end
  end
end
