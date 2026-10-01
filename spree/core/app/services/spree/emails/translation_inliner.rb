module Spree
  module Emails
    # Turns Spree's translation keys in a template into readable text in one
    # language, for a merchant who starts editing it:
    #
    #   {{ 'order_mailer.confirm_email.dear_customer' | t: name: order.customer_name }}
    #   # => Dear {{ order.customer_name }},
    #
    #   {% assign heading = 'order_mailer.confirm_email.order_summary' | t: number: order.number %}
    #   # => {% capture heading %}Order {{ order.number }} Summary{% endcapture %}
    #
    # A use it cannot turn into text exactly (a plural form, a missing
    # translation, a value it does not recognize) is left as it was, so the
    # template still renders the same.
    class TranslationInliner
      KEY = /'([a-z0-9_.]+)'/
      ARGUMENTS = /(?:\s*:\s*([^|}%]+?))?/
      OUTPUT = /\{\{-?\s*#{KEY}\s*\|\s*t#{ARGUMENTS}\s*(\|[^}]*?)?\s*-?\}\}/
      ASSIGN = /\{%-?\s*assign\s+(\w+)\s*=\s*#{KEY}\s*\|\s*t#{ARGUMENTS}\s*-?%\}/
      INTERPOLATION = /%\{(\w+)\}/

      # @param source [String, nil] a template's subject or body
      # @param locale [String, Symbol] the language to write the text in
      # @return [String, nil]
      def self.call(source, locale:)
        new(locale).call(source)
      end

      def initialize(locale)
        @locale = locale
      end

      def call(source)
        return source if source.blank?

        source.
          gsub(ASSIGN) { inline_assign(Regexp.last_match) || Regexp.last_match[0] }.
          gsub(OUTPUT) { inline_output(Regexp.last_match) || Regexp.last_match[0] }
      end

      private

      def inline_output(match)
        _, key, arguments, filters = match.to_a
        text = translation(key)
        return unless text

        if filters.present?
          return if arguments.present? || text.include?("'")

          "{{ '#{text}' #{filters.strip} }}"
        else
          interpolate(text, arguments) { |literal| ERB::Util.html_escape(literal) }
        end
      end

      def inline_assign(match)
        _, variable, key, arguments = match.to_a
        text = translation(key)
        return unless text

        if arguments.blank? && text.exclude?("'") && text !~ INTERPOLATION
          "{% assign #{variable} = '#{text}' %}"
        else
          body = interpolate(text, arguments) { |literal| ERB::Util.html_escape(literal) }
          body && "{% capture #{variable} %}#{body}{% endcapture %}"
        end
      end

      # Literal text is escaped by the caller's block; each `%{name}` becomes
      # the Liquid expression the template passed for it.
      def interpolate(text, arguments)
        values = parse_arguments(arguments)
        return unless values
        return if text.scan(INTERPOLATION).flatten.any? { |name| !values.key?(name) }

        text.split(INTERPOLATION).each_with_index.map do |part, index|
          index.odd? ? "{{ #{values[part]} }}" : yield(part)
        end.join
      end

      def parse_arguments(arguments)
        return {} if arguments.blank?

        arguments.split(/,\s*(?=\w+\s*:)/).to_h do |pair|
          name, expression = pair.split(':', 2).map(&:strip)
          return nil if name.blank? || expression.blank?

          [name, expression]
        end
      end

      def translation(key)
        text = I18n.t(key, scope: :spree, locale: @locale, default: nil)
        text if text.is_a?(String) && !text.include?('{{') && !text.include?('{%')
      end
    end
  end
end
