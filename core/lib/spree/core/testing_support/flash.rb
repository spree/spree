module Spree
  module Core
    module TestingSupport
      module Flash
        def assert_flash_notice(flash)
          if flash.is_a?(Symbol)
            flash = I18n.t(flash)
          end

          within("[class='flash notice']") do
            page.should have_content(flash)
          end
        end
      end
    end
  end
end
