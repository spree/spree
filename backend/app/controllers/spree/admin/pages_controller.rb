module Spree
  module Admin
    class PagesController < ResourceController
      before_action :load_data

      def index; end

      private

      def load_data
        @page_kinds = Spree::Page::PAGE_KINDS
      end
    end
  end
end
