module Spree
  class PermissionConfiguration
    # One grantable key with its kind and owning scope — the unit the
    # `/admin/permissions` discovery endpoint serializes.
    class Entry
      attr_reader :key, :kind, :scope

      def initialize(key:, kind:, scope:)
        @key = key
        @kind = kind
        @scope = scope
      end
    end
  end
end
