module Spree
  module CustomFields
    # `min` / `max` as a character count and `regex` as a pattern the whole
    # value must match, for the text types.
    module TextRules
      extend ActiveSupport::Concern

      REGEX_MAX_LENGTH = 255

      class_methods do
        def supported_validation_rules
          %w[min max regex]
        end

        def normalize_validation_bound(value, **)
          bound = Integer(value.to_s, 10, exception: false) unless [true, false].include?(value)
          bound if bound && bound >= 0
        end

        # Patterns a merchant writes run against every value saved, so only
        # those Ruby matches in linear time are taken; the timeout is a
        # backstop.
        #
        # @param source [Object] the pattern as sent
        # @return [Regexp, nil] nil when the pattern is not a usable regex
        def validation_regex(source)
          return unless source.is_a?(String) && source.present? && source.length <= REGEX_MAX_LENGTH

          # Compiled alone first, so a stray `)` cannot close the anchoring group.
          Regexp.new(source)
          regex = Regexp.new("\\A(?:#{source})\\z", timeout: 0.1)
          # `linear_time?` needs Ruby 3.3; without it no pattern can be proven safe.
          regex if Regexp.respond_to?(:linear_time?) && Regexp.linear_time?(regex)
        rescue RegexpError
          nil
        end
      end

      private

      def value_must_follow_definition_rules
        add_bound_errors(value.length, below: :too_short, above: :too_long)
        regex_must_match
      end

      def regex_must_match
        regex = self.class.validation_regex(definition_rules['regex'])
        return if regex.nil? || regex_matches?(regex)

        errors.add(:value, :regex_mismatch, message: I18n.t('spree.errors.messages.custom_field_regex_mismatch'))
      end

      def regex_matches?(regex)
        regex.match?(value)
      rescue Regexp::TimeoutError
        false
      end
    end
  end
end
