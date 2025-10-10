module Spree
  class SeoController < StoreController
    include BaseHelper
    include StorefrontHelper

    def robots
      render view: 'seo/robots', layout: false, content_type: 'text/plain', locals: { store: current_store }
    end

    def sitemap
      unless current_store.prefers_index_in_search_engines?
        head :not_found
        return
      end

      respond_to do |format|
        format.xml
        format.gzip do
          gz_xml = ActiveSupport::Gzip.compress(render_to_string(template: 'spree/seo/sitemap', formats: [:xml]))
          send_data(gz_xml, filename: 'sitemap.xml.gz', type: 'application/x-gzip', disposition: 'inline')
        end
      end
    end
  end
end
