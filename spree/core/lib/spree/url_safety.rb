# frozen_string_literal: true

require 'resolv'
require 'ipaddr'

module Spree
  module UrlSafety
    class SsrfError < StandardError; end

    BLOCKED_IP_RANGES = [
      IPAddr.new('0.0.0.0/8'),       # "This" network
      IPAddr.new('10.0.0.0/8'),      # Private (RFC 1918)
      IPAddr.new('127.0.0.0/8'),     # Loopback
      IPAddr.new('169.254.0.0/16'),  # Link-local / cloud metadata
      IPAddr.new('172.16.0.0/12'),   # Private (RFC 1918)
      IPAddr.new('192.168.0.0/16'),  # Private (RFC 1918)
      IPAddr.new('::1/128'),         # IPv6 loopback
      IPAddr.new('fc00::/7'),        # IPv6 ULA
      IPAddr.new('fe80::/10'),       # IPv6 link-local
    ].freeze

    # Validates that a URL does not resolve to a private/internal IP address.
    # Should be called at request time (not just validation time) to prevent DNS rebinding.
    #
    # @param url [String] the URL to validate
    # @raise [Spree::UrlSafety::SsrfError] if the URL resolves to a blocked IP
    # @return [void]
    def self.validate_url!(url)
      uri = URI.parse(url)
      hostname = uri.host

      raise SsrfError, "Invalid URL: missing hostname" if hostname.blank?

      addresses = Resolv.getaddresses(hostname)
      raise SsrfError, "Could not resolve hostname: #{hostname}" if addresses.empty?

      addresses.each do |addr_str|
        ip = IPAddr.new(addr_str)
        if BLOCKED_IP_RANGES.any? { |range| range.include?(ip) }
          raise SsrfError, "URL resolves to a blocked internal address"
        end
      end
    end
  end
end
