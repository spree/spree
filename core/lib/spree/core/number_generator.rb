module Spree
  module Core
    class NumberGenerator < Module
      DEFAULT_LENGTH = 9

      def initialize(options)
        @random     = Random.new
        @prefix     = options.fetch(:prefix)
        @length     = options.fetch(:length, DEFAULT_LENGTH)
        @letters    = options[:letters]
      end

      def included(host)
        generator_method   = method(:generate_permalink)
        generator_instance = self

        host.class_eval do
          validates(:number, presence: true, uniqueness: { allow_blank: true })

          before_validation do |instance|
            instance.number ||= generator_method.call(host)
          end

          define_singleton_method(:number_generator) { generator_instance }
        end
      end

      private

      def generate_permalink(host)
        length = @length

        candidate = @letters ? 36 : 10
        number = loop do
          random_token = SecureRandom.random_number(candidate**length).to_s(candidate).rjust(length, "0")
          break random_token unless host.exists?(number: random_token)
        end

        @prefix + number
      end
    end # Permalink
  end # Core
end # Spree
