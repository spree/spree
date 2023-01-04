module Spree
  module Api
    module V2
      module Storefront
        class StoresController < ::Spree::Api::V2::ResourceController
          before_action :update_options

          def current
            render_serialized_payload { serialize_resource(current_store) }
          end

          def export_google_rss_feed
            send_data export_google_rss, filename: 'products.rss', type: 'text/xml'
          end

          private

          def update_options
            @settings = Spree::GoogleFeedSetting.find_by(spree_store_id: current_store)
          end

          def export_google_rss
            Spree::Dependencies.export_google_rss_service.constantize.new.call(@settings)
          end

          def model_class
            Spree::Store
          end

          def resource
            @resource ||= scope.find_by!(code: params[:code])
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_store_serializer.constantize
          end
        end
      end
    end
  end
end
