module Spree
  module Api
    module V2
      module Platform
        class GoogleExportOptionsController < ResourceController
          def show
            @options = GoogleExportOption.find_by store: params[:store_id]
            @options.export
            send_file '/Users/weronika/Documents/export/spree_starter/products.rss'
          end
        end
      end
    end
  end
end
