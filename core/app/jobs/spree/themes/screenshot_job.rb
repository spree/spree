module Spree
  module Themes
    class ScreenshotJob < Spree::BaseJob
      queue_as Spree.queues.themes

      def perform(theme_id)
        theme = Spree::Theme.find(theme_id)

        browser = Ferrum::Browser.new
        browser.go_to(theme.store.formatted_url)

        Tempfile.create(['screenshot', '.png']) do |tempfile|
          browser.screenshot(path: tempfile.path)

          theme.skip_screenshot_update = true
          theme.screenshot.attach(
            io: File.open(tempfile.path),
            filename: "#{theme.store.name}-#{theme.name}-#{theme.updated_at}.png",
            content_type: 'image/png'
          )
          theme.save!
          theme.skip_screenshot_update = false
        end
      ensure
        browser&.quit
      end
    end
  end
end
