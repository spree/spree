module Spree
  module NumberGenerators
    # The 6.0 default: prefix + a counter that advances by one per document,
    # producing the invoice-like numbers merchants expect (`R1001`, `R1002`).
    #
    # The counter lives in {Spree::NumberSequence} rather than being derived
    # from the `number` column, because the column cannot answer "what comes
    # next": upgraded stores are full of 5.x random values that poison any
    # MAX-and-parse, string columns sort `R999` above `R1000`, concurrent
    # writers computing MAX+1 collide by construction, and a merchant-chosen
    # starting value is not a fact about any existing row.
    #
    # Numbering is mostly-gapless, never guaranteed gapless — a collision or
    # a rolled-back transaction consumes a value. Never present this as legal
    # invoice numbering.
    class Sequential < Base
      # Candidate values checked per query when jumping a stretch of numbers
      # another store already owns.
      SCAN_BATCH_SIZE = 100

      def generate(record)
        store = record.number_store
        raise_missing_store(record) if store.nil?

        resource_type = record.number_key.to_s
        value = Spree::NumberSequence.next_value(
          store: store,
          resource_type: resource_type,
          start_at: start_at_for(record)
        )

        candidate = compose(record, value)
        return candidate unless taken?(record, candidate)

        # The unique index is global, so a sibling store with the same format
        # can own a whole stretch of numbers — and stepping through it one
        # save attempt at a time would exhaust the concern's retry budget and
        # fail the save. Find the first free value in batches and jump the
        # counter past the stretch in one move instead.
        free_value = next_free_value(record, value)
        Spree::NumberSequence.advance_to(store: store, resource_type: resource_type, value: free_value)

        compose(record, free_value)
      end

      private

      def compose(record, value)
        "#{prefix_for(record)}#{value}#{suffix_for(record)}"
      end

      def taken?(record, candidate)
        record.class.unscoped.exists?(number: candidate)
      end

      def next_free_value(record, from)
        value = from

        loop do
          candidates = (value + 1..value + SCAN_BATCH_SIZE).index_by { |v| compose(record, v) }
          taken = record.class.unscoped.where(number: candidates.keys).pluck(:number)
          free = (candidates.keys - taken).first

          return candidates.fetch(free) if free

          value += SCAN_BATCH_SIZE
        end
      end

      # Says which setting is missing rather than letting the concern report
      # ten failed attempts and blame collisions.
      def raise_missing_store(record)
        raise Spree::HasNumber::GenerationError,
              "#{record.class.name} has no store to read numbering settings from — " \
              'define #number_store on the model or set Spree::Current.store'
      end

      # The starting value is part of the order-numbers settings card, so only
      # orders honour it; every other document type counts from the default.
      def start_at_for(record)
        return Spree::NumberSequence::DEFAULT_START unless record.number_key == :order

        store_preference(record, :order_number_sequence_start).to_i.nonzero? ||
          Spree::NumberSequence::DEFAULT_START
      end
    end
  end
end
