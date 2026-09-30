module Spree
  module Emails
    # The filters email templates can use, in addition to Liquid's standard
    # set. Names follow Shopify's where the meaning is the same, because that
    # is the Liquid most developers and agents already know.
    module Filters
      # @example {{ line_item.price | money }}
      # @param amount [String, Numeric, nil]
      # @param currency [String, nil] defaults to the email's currency
      # @return [String]
      def money(amount, currency = nil)
        return '' if amount.blank?

        Spree::Money.new(amount, currency: currency.presence || @context.registers[:currency]).to_s
      end

      # @example {{ order.total | money_with_currency }} # => "$10.00 USD"
      # @return [String]
      def money_with_currency(amount, currency = nil)
        return '' if amount.blank?

        Spree::Money.new(amount, currency: currency.presence || @context.registers[:currency], with_currency: true).to_s
      end

      # Formats a date in the store's time zone, never the server's. Takes a
      # named format from the locale's `date.formats` (`long`, `short`,
      # `default`), or a strftime pattern. A date with no time of day, such as
      # "2026-12-31", is shown as that day in every zone.
      #
      # @example {{ order.completed_at | date: 'long' }}
      # @example {{ 'now' | date: '%Y' }}
      # @return [String]
      def date(input, format = 'default')
        value = parse_time(input)
        return input.to_s if value.nil?

        value = value.in_time_zone(time_zone) unless value.instance_of?(Date)
        format = format.to_s

        return value.strftime(format) if format.include?('%')

        format = 'default' unless I18n.exists?("date.formats.#{format}")
        I18n.l(value.to_date, format: format.to_sym)
      end

      # Translates one of Spree's own keys, with interpolation.
      #
      # @example {{ 'order_mailer.confirm_email.dear_customer' | t: name: order.customer_name }}
      # @return [String]
      def t(key, options = {})
        interpolations = options.to_h.except('scope', 'default', :scope, :default).transform_keys(&:to_sym)

        Spree.t(key.to_s, **interpolations).to_s
      end

      # Marks a value as trusted HTML, so it is output without escaping. Only
      # for HTML that was sanitized when it was written.
      #
      # @example {{ product.description_html | raw }}
      # @return [ActiveSupport::SafeBuffer]
      def raw(input)
        input.to_s.html_safe
      end

      private

      def parse_time(input)
        case input
        when Time, DateTime, ActiveSupport::TimeWithZone then input
        when Date then input
        when 'now', 'today' then Time.current
        when /\A\d{4}-\d{2}-\d{2}\z/ then Date.iso8601(input)
        when String then Time.iso8601(input)
        end
      rescue ArgumentError
        nil
      end

      def time_zone
        Time.find_zone(@context.registers[:store]&.preferred_timezone) || Time.zone
      end
    end
  end
end
