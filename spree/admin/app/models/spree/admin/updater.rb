require 'net/http'
require 'json'
require 'uri'

module Spree
  module Admin
    class Updater
      SPREE_CLOUD_UPDATES_URL = 'https://spreecloud.io/updates.json'.freeze

      @updates = nil

      def self.update_available?
        fetch_updates.any?
      end

      def self.latest_release
        @latest_release ||= fetch_updates.first
      end

      def self.current_release
        @current_release ||= Spree.version
      end

      def self.fetch_updates
        @updates ||= Rails.cache.fetch("spree/admin/updater/fetch_updates/#{current_release}", expires_in: 1.day) do
          uri = URI(SPREE_CLOUD_UPDATES_URL)
          params = { version: current_release, environment: Rails.env, url: Spree::Store.current.url_or_custom_domain }
          uri.query = URI.encode_www_form(params)

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.open_timeout = 1 # 1s timeout for opening the connection
          http.read_timeout = 1 # 1s timeout for reading the response

          response = http.get(uri)
          return {} unless response.is_a?(Net::HTTPSuccess)

          JSON.parse(response.body)
        end
      rescue StandardError => e
        Rails.error.report(e)
        {}
      end
    end
  end
end
