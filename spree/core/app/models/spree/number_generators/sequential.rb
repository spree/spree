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
      def generate(record)
        store = record.number_store
        raise_missing_store(record) if store.nil?

        value = Spree::NumberSequence.next_value(
          store: store,
          resource_type: record.number_key.to_s,
          start_at: start_at_for(record)
        )

        "#{prefix_for(record)}#{value}#{suffix_for(record)}"
      end

      private

      # Says which setting is missing rather than letting the concern report
      # ten failed attempts and blame collisions.
      def raise_missing_store(record)
        raise Spree::HasNumber::GenerationError,
              "#{record.class.name} has no store to read numbering settings from — " \
              'define #number_store on the model or set Spree::Current.store'
      end

      # Orders honour the merchant's configured starting value; other
      # documents start at the same default so a store's numbers look
      # consistent across document types.
      def start_at_for(record)
        store_preference(record, :order_number_sequence_start).to_i.nonzero? ||
          Spree::NumberSequence::DEFAULT_START
      end
    end
  end
end
