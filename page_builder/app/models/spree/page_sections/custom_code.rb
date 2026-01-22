module Spree
  module PageSections
    class CustomCode < Spree::PageSection
      preference :custom_code, :string, default: ''

      def icon_name
        'code'
      end
    end
  end
end
