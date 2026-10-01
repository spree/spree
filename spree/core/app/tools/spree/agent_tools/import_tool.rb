module Spree
  module AgentTools
    # Shared behaviour for the tools that walk a CSV import through its
    # mapping step.
    #
    # They all have to find an import the same way — store-scoped, addressed
    # by whichever of its prefixed id or its number the merchant said aloud —
    # and getting that lookup right is the whole of their tenancy story, so it
    # lives in one place rather than three.
    class ImportTool < Spree::AgentTool
      protected

      # The import the caller named, or the most recent one matching `scope`
      # when they named none.
      #
      # @param id [String, nil] a prefixed id or an import number
      # @param scope [Symbol, nil] narrows the fallback, e.g. `:mapping`
      # @return [Spree::Import, nil]
      def find_import(id, status: nil)
        relation = imports_scope
        return if relation.nil?

        return latest_import(relation, status) if id.blank?

        by_prefixed_id(relation, id) || relation.find_by(number: id)
      end

      # The resource map is derived from the admin controllers, so an
      # installation without them has no imports entry — and a nil here must
      # read as "nothing found", never as a crash inside a rescue.
      #
      # @return [ActiveRecord::Relation, nil]
      def imports_scope
        ResourceMap.find('imports')&.scope_for(context)
      end

      # Whether the caller may see this import's contents.
      #
      # An import holds the uploaded file: its headings, a sample row of real
      # customer or product data, and the rows that failed. Reading that is
      # reading the resource being imported, so it takes that resource's own
      # scope rather than a generic settings key — the same per-import rule
      # the write path applies, because `read_settings` is not permission to
      # read a customer list someone uploaded.
      #
      # @param import [Spree::Import]
      # @return [Hash, nil] an error result to return, or nil when allowed
      def unauthorized_import(import)
        scope = import.class.try(:required_scope)
        return if scope.blank?
        return if context.holds?("read_#{scope}")

        { error: "You do not have permission to read a #{import_kind(import)} import." }
      end

      # What kind of import this is, in the merchant's words.
      #
      # @return [String]
      def import_kind(import)
        import.class.name.demodulize.underscore.tr('_', ' ')
      end

      private

      def latest_import(relation, status)
        relation = relation.where(status: status) if status.present?
        relation.order(created_at: :desc).first
      end

      # A value that is not a prefixed id at all raises rather than missing,
      # which is expected here: the merchant may well have said a number.
      def by_prefixed_id(relation, id)
        relation.find_by_prefix_id(id)
      rescue ArgumentError, NoMethodError
        nil
      end
    end
  end
end
