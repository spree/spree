module Spree
  module Api
    module V2
      module Storefront
        class GoogleExportOptionsController < ResourceController
          def export_rss_feed
            @options = GoogleExportOption.find_by(spree_store_id: params[:store_id])

            send_data export_google_rss, filename: 'products.rss', type: 'text/xml'
          end

          private

          def export_google_rss
            Spree::Dependencies.export_google_rss_service.constantize.new.call(@options)
          end
          #
          # def update_options
          #
          # end
        end
      end
    end
  end
end
