module Spree
  module Api
    module V2
      module Platform
        class BaseSerializer < ::Spree::Api::V2::BaseSerializer
          attribute :webhook_action, if: proc { |_record, params|
            params[:webhook_action].present?
          } do |_object, params|
            params[:webhook_action]
          end
        end
      end
    end
  end
end
