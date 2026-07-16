require 'net/http'
require 'json'
require 'uri'

module Spree
  module Admin
    class Updater
      SPREE_CLOUD_UPDATES_URL = 'https://spreecloud.io/updates.json'.freeze

      class << self
        def update_available?
          fetch_updates.any?
        end

        def latest_release
          fetch_updates.first
        end

        def current_release
          Spree.version
        end

        # Returns the releases newer than the running version, fetched from
        # spreecloud.io and cached for a day. The request carries only the
        # running version, +Rails.env+, the storefront URL and the anonymous
        # {Spree.install_id}. Failures are cached as an empty list too, so an
        # unreachable endpoint costs at most one timed-out request per day.
        #
        # @return [Array<Hash>] newer releases, newest first
        def fetch_updates
          Rails.cache.fetch("spree/admin/updater/fetch_updates/#{current_release}", expires_in: 1.day) do
            fetch_updates_from_spree_cloud
          end
        end

        private

        def fetch_updates_from_spree_cloud
          uri = URI(SPREE_CLOUD_UPDATES_URL)
          uri.query = URI.encode_www_form(
            version: current_release,
            environment: Rails.env,
            url: Spree::Current.store&.storefront_url,
            install_id: Spree.install_id
          )

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.open_timeout = 1 # 1s timeout for opening the connection
          http.read_timeout = 1 # 1s timeout for reading the response

          response = http.get(uri)
          response.is_a?(Net::HTTPSuccess) ? JSON.parse(response.body) : []
        rescue StandardError => e
          Rails.error.report(e)
          []
        end
      end
    end
  end
end
