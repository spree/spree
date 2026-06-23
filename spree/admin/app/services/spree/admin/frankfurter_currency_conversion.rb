# frozen_string_literal: true

require 'bigdecimal'
require 'json'
require 'net/http'
require 'uri'

module Spree
  module Admin
    # Fetches ECB-based FX rates from Frankfurter (https://www.frankfurter.app) and converts amounts.
    # Used only for admin UI suggestions; merchants should review converted prices before saving.
    class FrankfurterCurrencyConversion
      BASE_URL = 'https://api.frankfurter.app'

      class << self
        # @param amount [String, Numeric] amount in +from+ currency
        # @param from [String] ISO 4217 currency code
        # @param to [Array<String>] target ISO codes (excluding +from+)
        # @return [Hash<String, BigDecimal>] target code => converted amount (2 decimals)
        def convert(amount:, from:, to:)
          amt = begin
            BigDecimal(amount.to_s)
          rescue ArgumentError
            nil
          end
          return {} if amt.nil? || !amt.positive?

          from_code = from.to_s.upcase
          targets = normalize_targets(to, from_code)
          return {} if targets.empty?

          rates = cached_rates(from_code, targets)
          return {} if rates.blank?

          targets.each_with_object({}) do |code, out|
            rate = rates[code]
            next unless rate

            out[code] = (amt * BigDecimal(rate.to_s)).round(2)
          end
        end

        private

        def normalize_targets(to, from_code)
          Array(to).flat_map { |s| s.to_s.split(/[\s,]+/) }.map(&:strip).map(&:upcase).uniq.reject do |c|
            c.blank? || c == from_code || !::Money::Currency.find(c)
          end
        end

        def cached_rates(from_code, targets)
          cache_key = ['spree', 'admin', 'frankfurter', from_code, targets.sort.join('-'), Time.zone.today.to_s].join('/')
          Rails.cache.fetch(cache_key, expires_in: 12.hours) do
            fetch_rates(from_code, targets)
          end
        end

        def fetch_rates(from_code, targets)
          uri = URI("#{BASE_URL}/latest?from=#{CGI.escape(from_code)}&to=#{CGI.escape(targets.join(','))}")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.open_timeout = 3
          http.read_timeout = 5
          response = http.request(Net::HTTP::Get.new(uri.request_uri))
          return {} unless response.is_a?(Net::HTTPSuccess)

          data = JSON.parse(response.body)
          data['rates'] || {}
        rescue StandardError => e
          Rails.logger.warn("[FrankfurterCurrencyConversion] #{e.class}: #{e.message}")
          {}
        end
      end
    end
  end
end
