# frozen_string_literal: true

module Spree
  class AllowedOrigin < Spree.base_class
    # Loopback/development hosts that match any port, so storing `http://localhost`
    # keeps matching `http://localhost:3000`, `:4000`, etc.
    LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1 0.0.0.0].freeze

    has_prefix_id :ao

    include Spree::SingleStoreResource

    belongs_to :store, class_name: 'Spree::Store'

    validates :store, :origin, presence: true
    validates :origin, uniqueness: { scope: [:store_id, *spree_base_uniqueness_scope] }
    validate :origin_must_be_valid_http_url

    # Parses a URL into its comparable origin components, or nil when the URL is
    # invalid or not http(s). The host is downcased and has a single trailing dot
    # stripped, and the port is the URI default (80/443) when not explicitly given.
    #
    # @param url [String] the URL to parse
    # @return [Hash, nil] `{ scheme:, host:, port: }` or nil
    def self.parse_origin(url)
      uri = URI.parse(url.to_s)
      return nil unless uri.is_a?(URI::HTTP)
      return nil if uri.host.blank?

      { scheme: uri.scheme.downcase, host: uri.host.downcase.chomp('.'), port: uri.port }
    rescue URI::InvalidURIError
      nil
    end

    # Normalizes free-form input (possibly a bare host like `my-shop.vercel.app`)
    # to a canonical origin string (`scheme://host[:port]`, default ports
    # stripped), or nil when it's not a valid http(s) URL.
    #
    # @param raw [String, nil]
    # @return [String, nil]
    def self.normalize_origin(raw)
      raw = raw.to_s.strip
      return if raw.blank?

      candidate = raw.match?(%r{\Ahttps?://}i) ? raw : "https://#{raw}"
      parsed = parse_origin(candidate)
      return if parsed.nil?

      origin = "#{parsed[:scheme]}://#{parsed[:host]}"
      origin += ":#{parsed[:port]}" unless [80, 443].include?(parsed[:port])
      origin
    end

    # Whether this origin points at a loopback/development host ({LOOPBACK_HOSTS}),
    # e.g. the `http://localhost` origin seeded on install. Loopback origins are
    # ignored when deciding if a real storefront has been connected to the store.
    #
    # @return [Boolean]
    def loopback?
      LOOPBACK_HOSTS.include?(self.class.parse_origin(origin)&.dig(:host))
    end

    # Returns true if the given URL's origin matches this stored origin.
    #
    # Scheme and host must match exactly (host comparison is case- and trailing-dot-
    # insensitive). Port must also match, with the scheme default applied, so storing
    # `https://shop.com` matches `https://shop.com:443`. Loopback/development hosts
    # ({LOOPBACK_HOSTS}) are exempt from the port check, so `http://localhost` still
    # matches `http://localhost:3000`, `:4000`, etc.
    #
    # @param url [String] the candidate URL to check
    # @return [Boolean]
    def matches?(url)
      candidate = self.class.parse_origin(url)
      allowed = self.class.parse_origin(origin)
      return false if candidate.nil? || allowed.nil?
      return false unless allowed[:scheme] == candidate[:scheme]
      return false unless allowed[:host] == candidate[:host]

      LOOPBACK_HOSTS.include?(allowed[:host]) || allowed[:port] == candidate[:port]
    end

    private

    def origin_must_be_valid_http_url
      return if origin.blank?

      uri = URI.parse(origin)

      if self.class.parse_origin(origin).nil?
        errors.add(:origin, :invalid)
        return
      end

      # Origins must not have a path, query, or fragment
      if uri.path.present? && uri.path != '/'
        errors.add(:origin, :must_be_origin_only)
      end

      if uri.query.present? || uri.fragment.present?
        errors.add(:origin, :must_be_origin_only)
      end
    rescue URI::InvalidURIError
      errors.add(:origin, :invalid)
    end
  end
end
