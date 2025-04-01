require 'uri'
require 'net/http'

module Spree
  module Themes
    class ScreenshotJob < Spree::BaseJob
      queue_as Spree.queues.themes

      BASE_SCREENSHOT_API_URL = 'https://shot.screenshotapi.net/v3/screenshot'.freeze
      SCREENSHOT_OUTPUT = 'image'.freeze
      SCREENSHOT_FILE_TYPE = 'png'.freeze

      def perform(theme_id)
        theme = Spree::Theme.find(theme_id)

        Rails.logger.warn('Screenshot API token is missing') and return if screenshot_api_token.blank?

        return if theme.screenshot.attached?

        url = URI.encode_www_form_component("#{theme.store.url_or_custom_domain}?theme_id=#{theme_id}")
        query_params = {
          token: screenshot_api_token,
          url: url,
          output: SCREENSHOT_OUTPUT,
          file_type: SCREENSHOT_FILE_TYPE,
          retina: true,
          enable_caching: true
        }
        query = "#{BASE_SCREENSHOT_API_URL}?#{query_params.to_query}"

        # Send a GET request to the API
        uri = URI.parse(query)
        response = Net::HTTP.get_response(uri)

        case response.code
        when '301', '302'
          redirect_uri = response['location']
          redirect_uri = URI.parse(redirect_uri)
          response = Net::HTTP.get_response(redirect_uri)
          save_screenshot(theme, response)
        when '200'
          save_screenshot(theme, response)
        else
          Rails.error.report('Screenshot API returned non-200 status code')
        end
      end

      private

      def screenshot_api_token
        @screenshot_api_token ||= Spree.screenshot_api_token
      end

      def save_screenshot(theme, response)
        temp_file_path = "theme-screenshot-#{theme.id}.png"

        # Create a temporary file
        File.open(temp_file_path, "wb") do |file|
          file.write(response.body)
        end

        # Open the file for reading to attach it
        file = File.open(temp_file_path, "rb")

        # Attach the file
        theme.screenshot.attach(
          io: file,
          filename: "theme-screenshot-#{theme.id}.#{SCREENSHOT_FILE_TYPE}",
          content_type: "image/#{SCREENSHOT_FILE_TYPE}"
        )
        theme.save!

        # Close the file before attempting to delete it
        file.close

        # Remove the temporary file
        File.delete(temp_file_path) if File.exist?(temp_file_path)
      end
    end
  end
end
