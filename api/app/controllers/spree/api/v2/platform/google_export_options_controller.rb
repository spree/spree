module Spree
  module Api
    module V2
      module Platform
        class GoogleExportOptionsController < ResourceController
          def show
            @options = GoogleExportOption.find_by store: params[:store_id]

            send_data @options.export, filename: 'products.rss', type: 'text/xml'
          end
        end
      end
    end
  end
end
