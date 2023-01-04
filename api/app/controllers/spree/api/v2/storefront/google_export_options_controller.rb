module Spree
  module Api
    module V2
      module Storefront
        class GoogleExportOptionsController < ResourceController
          def show
            @options = GoogleExportOption.find_by(spree_store_id: params[:store_id])

            send_data @options.export, filename: 'products.rss', type: 'text/xml'
          end
        end
      end
    end
  end
end
