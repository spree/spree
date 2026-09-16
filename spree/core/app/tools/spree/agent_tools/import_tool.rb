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
