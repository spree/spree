require 'net/http'
require 'json'
require 'uri'

module Spree
  module Admin
    class Updater
      SPREE_CLOUD_UPDATES_URL = 'https://spreecloud.io/updates.json'

      @updates = nil

      def self.update_available?
        fetch_updates.any?
      end

      def self.fetch_updates
        @updates ||= Rails.cache.fetch("spree/admin/updater/fetch_updates/#{Spree.version}", expires_in: 1.day) do
          uri = URI(SPREE_CLOUD_UPDATES_URL)
          params = { version: Spree.version }
          uri.query = URI.encode_www_form(params)

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.open_timeout = 1 # 1s timeout for opening the connection
          http.read_timeout = 1 # 1s timeout for reading the response

          response = http.get(uri)
          return {} unless response.is_a?(Net::HTTPSuccess)

          JSON.parse(response.body)
        end
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, JSON::ParserError => e
        Rails.logger.error("Failed to fetch Spree updates: #{e.message}")
        {}
      end
    end
  end
end
