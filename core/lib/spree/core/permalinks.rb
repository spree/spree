module Spree
  module Core
    class Permalinks < Module

      RAND = Random.new
      BASE = 10

      DEFAULT_LENGTH = 9

      def initialize(options)
        @prefix = options.fetch(:prefix)
        @length = options.fetch(:length, DEFAULT_LENGTH)
      end

      def included(host)
        host.class_eval do
          define_singleton_method :find_by_param do |*args|
            find_by_number(*args)
          end
          define_singleton_method :find_by_param! do |*args|
            find_by_number!(*args)
          end
        end

        generator = method(:generate_permalink)

        host.before_validation do |instance|
          instance.number ||= generator.call(host)
        end
      end

    private

      def generate_permalink(host)
        length = @length

        loop do
          candidate = new_candidate(length)
          return candidate unless host.exists?(number: candidate)

          # If over half of all possible options are taken add another digit.
          length += 1 if host.count > Rational(BASE ** length, 2)
        end
      end

      def new_candidate(length)
        '%s%0.*i' % [@prefix, length, RAND.rand(BASE ** length)]
      end

    end # Permalink
  end # Core
end # Spree
