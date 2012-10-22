module Spree
  module TestingSupport
    module Flash
      def assert_flash_success(flash)
        flash = convert_flash(flash)

        within("[class='flash success']") do
          page.should have_content(flash)
        end
      end

      def assert_successful_update_message(resource)
        flash = I18n.t(:successfully_updated, :resource => I18n.t(resource))
        assert_flash_success(flash)
      end

      private

      def convert_flash(flash)
        if flash.is_a?(Symbol)
          flash = I18n.t(flash)
        end
        flash
      end
    end
  end
end
