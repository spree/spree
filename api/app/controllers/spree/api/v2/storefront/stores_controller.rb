module Spree
  module Api
    module V2
      module Storefront
        class StoresController < ::Spree::Api::V2::ResourceController
          def current
            render_serialized_payload { serialize_resource(current_store) }
          end

          def data_feeds_google_rss_feed
            send_data data_feeds_google_rss_service.value[:file], filename: 'products.rss', type: 'text/xml'
          end

          private

          def settings
            @settings ||= Spree::DataFeedSetting.find_by!(spree_store_id: current_store, uuid: params[:unique_url], enabled: true)
          end

          def data_feeds_google_rss_service
            Spree::Dependencies.data_feeds_google_rss_service.constantize.new.call(settings)
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
