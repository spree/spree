module Spree
  module Admin
    module RtlHelper
      def rtl_locale?(locale = I18n.locale)
        Spree::Admin::Rtl.rtl_locale?(locale)
      end

      def html_dir(locale = I18n.locale)
        Spree::Admin::Rtl.html_dir(locale)
      end
    end
  end
end
