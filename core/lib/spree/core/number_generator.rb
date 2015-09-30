module Spree
  module Core
    class NumberGenerator < Module
      BASE           = 10
      DEFAULT_LENGTH = 9
      NUMBERS        = (0..9).to_a.freeze
      LETTERS        = ('A'..'Z').to_a.freeze

      attr_accessor :prefix, :length

      def initialize(options)
        @random     = Random.new
        @prefix     = options.fetch(:prefix)
        @length     = options.fetch(:length, DEFAULT_LENGTH)
        @candidates = NUMBERS + (options[:letters] ? LETTERS : [])
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

        loop do
          candidate = new_candidate(length)
          return candidate unless host.exists?(number: candidate)

          # If over half of all possible options are taken add another digit.
          length += 1 if host.count > Rational(BASE**length, 2)
        end
      end

      def new_candidate(length)
        @prefix + length.times.map { @candidates.sample(random: @random) }.join
      end
    end # Permalink
  end # Core
end # Spree
