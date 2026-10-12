require 'net/http'

module Spree
  # Asks spreecloud.io which Spree releases are newer than the running one,
  # and reports usage with the same request. The answer is cached for a day,
  # so at most one admin request a day waits on it, for no more than the two
  # one-second timeouts. A failed check is cached for an hour, so a passing
  # outage costs one slow request an hour and never hides a release for long.
  #
  # The +version+, +environment+, +url+ and +install_id+ query keys are what
  # Spree 5 sent, and the endpoint still serves 5.x installs with them. They
  # are never renamed; new keys only ever go beside them.
  class UpdateCheck
    ENDPOINT = 'https://spreecloud.io/updates.json'.freeze
    RELEASES_URL = 'https://github.com/spree/spree/releases/tag/'.freeze
    RELEASE_TAG = /\Av\d+(\.[0-9a-z]+)*\z/
    CACHE_TTL = 1.day
    FAILURE_TTL = 1.hour
    OPEN_TIMEOUT = 1
    READ_TIMEOUT = 1
    # The read timeout applies to each read, not the whole response, so a
    # slowly trickling answer needs an overall deadline as well.
    TOTAL_TIMEOUT = 2
    # Order-of-magnitude buckets: enough to tell a hobby install from a large
    # merchant, never an exact figure.
    BUCKETS = {
      0..0 => '0',
      1..9 => '1-9',
      10..99 => '10-99',
      100..999 => '100-999',
      1_000..9_999 => '1k-9k',
      10_000..99_999 => '10k-99k'
    }.freeze
    LARGEST_BUCKET = '100k+'.freeze

    class << self
      # @return [Boolean] false when the operator turned the check off
      def enabled?
        Spree::Config.update_check_enabled && !env_flag?('SPREE_UPDATE_CHECK_DISABLED')
      end

      # When false, the check still runs but sends the running version only.
      #
      # @return [Boolean]
      def telemetry_enabled?
        Spree::Config.telemetry_enabled &&
          !env_flag?('SPREE_TELEMETRY_DISABLED') &&
          !env_flag?('DO_NOT_TRACK')
      end

      # The cached answer, fetched from the endpoint when there is none.
      #
      # @return [Spree::UpdateStatus]
      def status
        return Spree::UpdateStatus.new(current_version: Spree.version, enabled: false) unless enabled?

        result = Rails.cache.read(cache_key) || refresh

        Spree::UpdateStatus.new(current_version: Spree.version, checked_at: result[:checked_at], releases: result[:releases])
      end

      # @return [Hash] the query string the endpoint receives
      def query
        return { version: Spree.version } unless telemetry_enabled?

        {
          version: Spree.version,
          environment: Rails.env,
          url: Spree::Store.default&.storefront_url,
          install_id: Spree.install_id,
          ruby: RUBY_VERSION,
          rails: Rails.version,
          database: ActiveRecord::Base.connection_db_config.adapter,
          gems: Gem.loaded_specs.keys.grep(/\Aspree_/).sort.join(','),
          dashboard: dashboard_served?,
          stores: bucket(Spree::Store.count),
          products: bucket(Spree::Product.count),
          orders: bucket(Spree::Order.complete.count),
          sellers: seller_bucket
        }.compact
      end

      private

      def refresh
        releases = fetch_releases
        result = { releases: releases || [], checked_at: Time.current }
        Rails.cache.write(cache_key, result, expires_in: releases ? CACHE_TTL : FAILURE_TTL)
        result
      end

      # Nil when the check failed, for whatever reason: an update notice is
      # never worth failing the admin's request over, including a database
      # error while counting for the usage fields.
      def fetch_releases
        uri = URI(ENDPOINT)
        uri.query = URI.encode_www_form(query)

        response = Timeout.timeout(TOTAL_TIMEOUT) do
          Net::HTTP.start(uri.host, uri.port, use_ssl: true, max_retries: 0,
                                              open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
            http.get(uri.request_uri)
          end
        end
        return unless response.is_a?(Net::HTTPSuccess)

        newer_releases(JSON.parse(response.body))
      rescue StandardError => e
        Rails.error.report(e, handled: true, severity: :warning, source: 'spree.update_check')
        nil
      end

      # The endpoint already filters by version; this does it again and
      # builds each link from the tag, so whatever comes back over the wire
      # never reaches the dashboard as a URL. Release candidates are only
      # offered to installs already running one.
      def newer_releases(payload)
        current = Gem::Version.new(Spree.version)

        Array(payload).filter_map { |release|
          tag = release.is_a?(Hash) ? release['tag_name'].to_s : ''
          next unless tag.match?(RELEASE_TAG)

          version = Gem::Version.new(tag.delete_prefix('v'))
          next unless version > current
          next if version.prerelease? && !current.prerelease?

          { version: version.to_s, url: "#{RELEASES_URL}#{tag}", published_at: parse_time(release['published_at']) }
        }.sort_by { |release| Gem::Version.new(release[:version]) }.reverse
      end

      def parse_time(value)
        Time.iso8601(value.to_s)
      rescue ArgumentError
        nil
      end

      def bucket(count)
        BUCKETS.find { |range, _| range.cover?(count) }&.last || LARGEST_BUCKET
      end

      def seller_bucket
        count = Spree::Seller.count
        bucket(count) if count.positive?
      end

      def dashboard_served?
        (defined?(Spree::Dashboard) && Spree::Dashboard.dist_path.present?) || Spree::Config.dashboard_url.present?
      end

      def env_flag?(name)
        ActiveModel::Type::Boolean.new.cast(ENV[name].presence) == true
      end

      def cache_key
        "spree/update_check/#{Spree.version}"
      end
    end
  end
end
