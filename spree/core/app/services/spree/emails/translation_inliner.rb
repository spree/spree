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
      # Tags are found with simple patterns and read with string handling, so
      # matching stays linear on any input a merchant pastes in.
      OUTPUT_TAG = /\{\{([^{}]*)\}\}/
      ASSIGN_TAG = /\{%([^{}%]*)%\}/
      TRANSLATED = /\A'([a-z0-9_.]+)'\s*\|\s*t\b/
      ASSIGNED = /\Aassign\s+(\w+)\s*=\s*/
      INTERPOLATION = /%\{(\w+)\}/

      # @param source [String, nil] a template's subject or body
      # @param locale [String, Symbol] the language to write the text in
      # @param escape [Boolean] whether the text is HTML: false for a subject,
      #   which renders unescaped as a mail header
      # @return [String, nil]
      def self.call(source, locale:, escape: true)
        new(locale, escape).call(source)
      end

      def initialize(locale, escape = true)
        @locale = locale
        @escape = escape
      end

      def call(source)
        return source if source.blank?

        source.
          gsub(ASSIGN_TAG) { |tag| inline_assign(markup(Regexp.last_match[1])) || tag }.
          gsub(OUTPUT_TAG) { |tag| inline_output(markup(Regexp.last_match[1])) || tag }
      end

      private

      # A tag's content without whitespace control dashes or padding.
      def markup(content)
        content.delete_prefix('-').delete_suffix('-').strip
      end

      # `'key' | t`, `'key' | t: name: value` and `'key' | t | filter`, split into
      # the key, its arguments and the filters after it.
      def translation_call(markup)
        match = TRANSLATED.match(markup)
        return unless match

        rest = match.post_match.strip
        if rest.start_with?(':')
          arguments, filters = rest.delete_prefix(':').split('|', 2)
          [match[1], arguments.strip, filters&.strip]
        elsif rest.start_with?('|')
          [match[1], nil, rest.delete_prefix('|').strip]
        elsif rest.empty?
          [match[1], nil, nil]
        end
      end

      def inline_output(markup)
        key, arguments, filters = translation_call(markup)
        text = key && translation(key)
        return unless text

        if filters.present?
          return if arguments.present? || text.include?("'")

          "{{ '#{text}' | #{filters} }}"
        else
          interpolate(text, arguments) { |literal| literal_text(literal) }
        end
      end

      def inline_assign(markup)
        assigned = ASSIGNED.match(markup)
        return unless assigned

        variable = assigned[1]
        key, arguments, filters = translation_call(assigned.post_match)
        text = key && filters.nil? && translation(key)
        return unless text

        if arguments.blank? && text.exclude?("'") && text !~ INTERPOLATION
          "{% assign #{variable} = '#{text}' %}"
        else
          body = interpolate(text, arguments) { |literal| literal_text(literal) }
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

      def literal_text(literal)
        @escape ? ERB::Util.html_escape(literal) : literal
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
