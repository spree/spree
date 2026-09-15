module Spree
  class PermissionConfiguration
    # A registered catalog scope. Yields one or two grantable keys and maps
    # them to the CanCanCan resources they cover.
    class Scope
      attr_reader :name, :group

      # @param name [Symbol] scope identifier (`:orders`)
      # @param group [Symbol] UI grouping for the permission pickers
      # @param resources [Proc, Array] CanCanCan resources covered by this
      #   scope; pass a lambda so model classes resolve lazily
      # @param write [Boolean] whether a `write_<name>` key exists
      # @param audiences [Array<Symbol>] every audience whose roles may hold
      #   this scope's keys — the store's own back office is `:store`, and
      #   is the whole list unless the registration says otherwise
      def initialize(name:, group:, resources:, write: true, audiences: [STAFF_AUDIENCE], read_only_for: [])
        @name = name.to_sym
        @group = group.to_sym
        @resources = resources
        @write = write
        @audiences = Array(audiences).map(&:to_sym).freeze
        @read_only_for = Array(read_only_for).map(&:to_sym).freeze
      end

      # @return [Boolean]
      def write?
        @write
      end

      # @return [Array<Symbol>] every audience this scope is grantable to
      def audiences
        @audiences
      end

      # @param audience [Symbol, String, nil]
      # @return [Boolean]
      def grantable_to?(audience)
        return false if audience.blank?

        @audiences.include?(audience.to_s.to_sym)
      end

      # @return [Array<Class, Symbol>]
      def resources
        Array(@resources.respond_to?(:call) ? @resources.call : @resources)
      end

      # @return [String]
      def read_key
        "#{READ_PREFIX}#{name}"
      end

      # @return [String, nil]
      def write_key
        "#{WRITE_PREFIX}#{name}" if write?
      end

      # @return [Array<String>] the grantable keys, read first
      def keys
        [read_key, write_key].compact
      end

      # The keys one audience may hold. A scope the operator writes can
      # still be read-only for somebody else — product types are the case:
      # staff define them, a seller only picks from them.
      #
      # @param audience [Symbol, String, nil]
      # @return [Array<String>]
      def keys_for(audience)
        return [read_key] if @read_only_for.include?(audience.to_s.to_sym)

        keys
      end
    end
  end
end
