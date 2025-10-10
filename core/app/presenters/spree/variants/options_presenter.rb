module Spree
  module Variants
    class OptionsPresenter
      WORDS_CONNECTOR = ', '.freeze

      attr_reader :variant

      delegate :option_values, to: :variant

      def initialize(variant)
        @variant = variant
      end

      def to_sentence
        options = option_values
        options = sort_options(options)
        options = present_options(options)

        join_options(options)
      end

      def to_hash
        options = option_values
        options = sort_options(options)
        options = present_options_as_hash(options)

        join_hash_options(options)
      end

      private

      def sort_options(options)
        if options.first&.association(:option_type)&.loaded?
          options.sort_by { |o| o.option_type.position }
        else
          options.includes(:option_type).sort_by { |o| o.option_type.position }
        end
      end

      def present_options(options)
        options.map do |ov|
          method = "present_#{ov.option_type.name}_option"

          respond_to?(method, true) ? send(method, ov) : present_option(ov)
        end
      end

      def present_color_option(option)
        "#{option.option_type.presentation}: #{option.presentation}"
      end

      def present_option(option)
        "#{option.option_type.presentation}: #{option.presentation}"
      end

      def join_options(options)
        options.to_sentence(words_connector: WORDS_CONNECTOR, two_words_connector: WORDS_CONNECTOR)
      end

      def present_options_as_hash(options)
        options.map do |ov|
          method = "present_#{ov.option_type.name}_option_as_hash"

          respond_to?(method, true) ? send(method, ov) : present_option_as_hash(ov)
        end
      end

      def present_option_as_hash(option)
        {}.tap do |hash|
          hash.store(option.option_type.presentation.downcase, option.presentation)
        end
      end

      def join_hash_options(options)
        return {} if options.empty?

        options.inject(:merge).symbolize_keys
      end
    end
  end
end
