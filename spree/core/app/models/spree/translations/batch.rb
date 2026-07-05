module Spree
  module Translations
    # Atomically upserts translations across MANY records of (possibly)
    # different translatable resource types in one operation — the domain
    # behind +POST /api/v3/admin/translations/batch+.
    #
    # The input is a flat list of independent registry writes, each naming its
    # own +resource_type+ + +resource_id+ (no nested parent-owns-children
    # payload), so there's no per-model branching. Records are resolved within
    # the current store, then upserted in a single transaction: any failure
    # rolls back the whole batch and surfaces the offending entry's index via a
    # typed {EntryError}.
    #
    # @example
    #   Spree::Translations::Batch.new(entries).process! do |record|
    #     authorize!(:update, record)
    #   end
    class Batch
      include ActiveModel::Model

      # Raised when the batch payload is empty (or not a list of entries).
      class EmptyError < StandardError; end

      # Raised when an entry can't be processed — unknown/non-translatable
      # resource type, a record missing in the current store, or an invalid
      # save. Carries the entry +index+ so the caller can map the error back to
      # the offending row.
      class EntryError < StandardError
        attr_reader :index

        def initialize(message, index)
          @index = index
          super(message)
        end
      end

      # @return [Array<Spree.base_class>] records written by the last successful {#process!}
      attr_reader :records

      # @param entries [Array<Hash>] [{ resource_type:, resource_id:, values: { locale => { field => value } } }]
      def initialize(entries)
        @entries = Array(entries)
        @records = []
      end

      # Distinct +write_<resource>+ scopes a caller needs to authorize this
      # batch — one per resource type present. Lets the API layer gate an
      # API-key request without re-deriving scope names.
      # @return [Array<String>]
      def required_scopes
        @entries.map { |entry| "write_#{entry[:resource_type].to_s.pluralize}" }.uniq
      end

      # Upserts every entry in one transaction. Yields each resolved record
      # before it is written so the caller can authorize it; a raised error in
      # the block (or any entry failure) rolls back the whole batch.
      #
      # @yieldparam record [Spree.base_class] the resolved record, pre-write
      # @raise [EmptyError] when there are no entries
      # @raise [EntryError] when an entry can't be resolved or saved
      # @return [Array<Spree.base_class>] the written records
      def process!
        raise EmptyError if @entries.empty?

        @records = []
        ActiveRecord::Base.transaction do
          @entries.each_with_index do |entry, index|
            record = resolve_record!(entry, index)
            yield record if block_given?
            upsert!(record, entry[:values], index)
            @records << record
          end
        end
        @records
      end

      private

      def upsert!(record, values, index)
        record.upsert_translations(values)
      rescue ActiveRecord::RecordInvalid => e
        raise EntryError.new(e.record.errors.full_messages.join(', '), index)
      end

      def resolve_record!(entry, index)
        klass = resource_class(entry[:resource_type])
        raise EntryError.new("Unknown translatable resource type: #{entry[:resource_type]}", index) if klass.nil?

        relation = klass.respond_to?(:for_store) ? klass.for_store(Spree::Store.current) : klass
        relation.find_by_prefix_id!(entry[:resource_id])
      rescue ActiveRecord::RecordNotFound
        raise EntryError.new("Resource not found: #{entry[:resource_id]}", index)
      end

      # Memoized per instance so a batch of N entries doesn't rebuild the
      # registry map N times. A Batch is request-scoped, so dev-mode class
      # reloads are still picked up on the next request.
      def resource_class(token)
        @resource_class_map ||= Hash.new { |h, t| h[t] = Spree::Translations.resource_class(t) }
        @resource_class_map[token]
      end
    end
  end
end
