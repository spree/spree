module Spree
  module Api
    module V2
      module Platform
        class BaseSerializer < ::Spree::Api::V2::BaseSerializer
          attribute :webhook_metadata, if: proc { |_record, params|
            params.present? && params[:webhook_metadata] == true
          } do |_object, params|
            {
              event_created_at: params[:event_created_at],
              event_id: params[:event_id],
              event_type: params[:event_type]
            }
          end
        end
      end
    end
  end
end
