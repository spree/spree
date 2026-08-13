module Spree
  module Core
    # @deprecated Use {Spree::HasNumber} instead. Removed in Spree 6.1.
    #
    #   # before
    #   include Spree::Core::NumberGenerator.new(prefix: 'R')
    #
    #   # after
    #   has_spree_number prefix: 'R'
    #
    # Kept as a shell so existing models and extension decorators keep
    # working for one release. Including it wires up {Spree::HasNumber} with
    # the given prefix, which means numbers now follow the store's format
    # preference (sequential by default) rather than always being random.
    # Hosts that need the old random numbers should switch the store's
    # `document_number_format` preference to `random`, or register their own
    # generator — see docs/plans/6.0-document-numbers.md.
    #
    # `length:` and `letters:` are accepted and ignored: they described the
    # random format, which is now the strategy's business rather than the
    # model's.
    class NumberGenerator < Module
      DEFAULT_LENGTH = 9

      attr_accessor :prefix, :length

      def initialize(options)
        @prefix  = options.fetch(:prefix)
        @length  = options.fetch(:length, DEFAULT_LENGTH)
        @letters = options[:letters]

        Spree::Deprecation.warn(
          'Spree::Core::NumberGenerator is deprecated and will be removed in ' \
          "Spree 6.1. Replace `include Spree::Core::NumberGenerator.new(prefix: '#{@prefix}')` " \
          "with `has_spree_number prefix: '#{@prefix}'`. " \
          'See docs/plans/6.0-document-numbers.md.'
        )
      end

      def included(host)
        prefix = @prefix

        host.class_eval do
          # Hosts inheriting from Spree::Base already have the concern; a bare
          # ActiveRecord model (some extensions) needs it included here.
          include Spree::HasNumber unless respond_to?(:has_spree_number)

          has_spree_number prefix: prefix
        end
      end
    end
  end
end
