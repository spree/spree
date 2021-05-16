module Spree
  module Admin
    class CmsPagesController < ResourceController
      before_action :load_data

      def load_data
        @page_kinds = Spree::CmsPage::PAGE_KINDS
      end
    end
  end
end
