module Spree
  # Per-store, per-resource counter behind sequential document numbering
  # (docs/plans/6.0-document-numbers.md). One row per numbered resource type
  # a store actually uses; nothing outside {Spree::NumberGenerators::Sequential}
  # reads them.
  #
  # This exists because the `number` column cannot say what comes next — see
  # the generator for why deriving it from data is not an option. Postgres
  # has native sequences, MySQL and SQLite do not, so a locked counter row is
  # the portable equivalent.
  class NumberSequence < Spree.base_class
    DEFAULT_START = 1001

    belongs_to :store, class_name: 'Spree::Store'

    validates :resource_type, presence: true,
                              uniqueness: { scope: :store_id, case_sensitive: false }
    validates :value, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    class << self
      # Advances the counter and returns the value to use. The row is locked
      # for the increment, so concurrent checkouts hand out distinct numbers
      # instead of racing on the same one.
      #
      # @param store [Spree::Store]
      # @param resource_type [String] e.g. 'order'
      # @param start_at [Integer] first value handed out for a fresh counter
      # @return [Integer]
      # Whether a counter has already handed out a number, which is what makes
      # the store's starting-value setting inert from then on. The dashboard
      # reads this to say so rather than letting a merchant set a value that
      # silently does nothing.
      #
      # @param store [Spree::Store]
      # @param resource_type [String]
      # @return [Boolean]
      def started?(store:, resource_type: 'order')
        return false if store.nil?

        exists?(store: store, resource_type: resource_type)
      end

      def next_value(store:, resource_type:, start_at: DEFAULT_START)
        sequence = find_or_create_sequence(store, resource_type, start_at)

        sequence.with_lock do
          sequence.increment!(:value)
          sequence.value
        end
      end

      private

      # A fresh counter is seeded one below the configured start so the first
      # increment hands out `start_at` itself.
      #
      # Two writers can reach the insert together — the loser sees either the
      # unique index (RecordNotUnique) or the uniqueness validation reading
      # the winner's committed row (RecordInvalid). Both mean the same thing:
      # the row now exists, so read it.
      def find_or_create_sequence(store, resource_type, start_at)
        seed = [start_at.to_i - 1, 0].max

        find_or_create_by!(store: store, resource_type: resource_type) do |sequence|
          sequence.value = seed
        end
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        find_by!(store: store, resource_type: resource_type)
      end
    end
  end
end
