module Spree
  module NumberGenerators
    # Produces candidate document numbers for models including
    # {Spree::HasNumber}. Uniqueness is the concern's job, not the
    # generator's — a generator only has to propose.
    #
    # Subclass and register to take over numbering for one resource or all of
    # them (docs/plans/6.0-document-numbers.md):
    #
    #   class MyApp::BranchOrderNumbers < Spree::NumberGenerators::Base
    #     def generate(record)
    #       "#{record.number_store.code}-#{record.created_at.year}-#{...}"
    #     end
    #   end
    #
    #   Spree.number_generators[:order] = 'MyApp::BranchOrderNumbers'
    class Base
      # @param record [ActiveRecord::Base] the record being numbered; reaches
      #   its store through `#number_store` and its prefix through
      #   `.number_prefix`
      # @return [String] a candidate number
      def generate(record)
        raise NotImplementedError, "#{self.class.name} must implement #generate"
      end

      protected

      # The prefix a merchant configured for this resource, falling back to
      # the model's code-level default. Only orders are configurable in 6.0.
      #
      # @return [String]
      def prefix_for(record)
        return record.class.number_prefix unless record.number_key == :order

        store_preference(record, :order_number_prefix) || record.class.number_prefix
      end

      # @return [String]
      def suffix_for(record)
        return '' unless record.number_key == :order

        store_preference(record, :order_number_suffix).to_s
      end

      # @return [Object, nil] nil when there is no store to read, so callers
      #   fall back to their own defaults rather than to a store's blank
      def store_preference(record, name)
        store = record.number_store
        return if store.nil?

        value = store.public_send(:"preferred_#{name}")
        value.presence
      end
    end
  end
end
