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
        flash = Spree.t(:successfully_updated, :resource => Spree.t(resource))
        assert_flash_success(flash)
      end

      private

      def convert_flash(flash)
        if flash.is_a?(Symbol)
          flash = Spree.t(flash)
        end
        flash
      end
    end
  end
end
