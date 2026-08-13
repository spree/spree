module Spree
  # Declarative human-readable document number for models whose number is
  # shown to a person — on an order confirmation, a supplier purchase order,
  # a transfer slip taped to a box (docs/plans/6.0-document-numbers.md).
  #
  #   class Spree::Order < Spree.base_class
  #     has_spree_number prefix: 'R'
  #   end
  #
  # Included into {Spree::Base}, so the macro is available on every model and
  # nothing happens until one calls it — no callback, no class attributes.
  #
  # The concern owns the parts that never vary: assigning a number before
  # validation, retrying on collision, and rescuing the unique-index race.
  # Which string to try is the generator's job, and the generator is resolved
  # per record at save time rather than frozen at class-definition time —
  # that is what lets a merchant switch formats in settings, and an extension
  # swap the whole strategy through {Spree.number_generators}, without
  # reopening this class.
  module HasNumber
    extend ActiveSupport::Concern

    # A generator that keeps colliding is a bug in the generator, not bad
    # luck. Bail loudly rather than spinning in a save.
    MAX_ATTEMPTS = 10

    class GenerationError < StandardError; end

    class_methods do
      # @param prefix [String] leads every number for this model, e.g. 'R'
      # @param key [Symbol] registry key; defaults to the demodulized,
      #   underscored model name (`Spree::StockTransfer` → `:stock_transfer`)
      def has_spree_number(prefix:, key: nil)
        class_attribute :number_prefix, default: prefix, instance_writer: false
        class_attribute :number_key,
                        default: (key || name.demodulize.underscore).to_sym,
                        instance_writer: false

        before_validation :generate_number, on: :create
      end

      # Whether this model opted into generated numbers. The concern lives on
      # every model through {Spree::Base}, so ask rather than assuming.
      #
      # @return [Boolean]
      def has_spree_number?
        respond_to?(:number_key)
      end

      # The generator instance for this model, resolved fresh each call so a
      # host app can swap the registry entry at runtime (and so Zeitwerk
      # reloads pick up a redefined class in development).
      #
      # @param store [Spree::Store, nil] the record's store, whose format
      #   preference picks the strategy when nothing is registered
      # @return [Spree::NumberGenerators::Base]
      def number_generator(store: nil)
        Spree.number_generators.for(number_key, store: store)
      end
    end

    # Assigns a number unless one was supplied. Public so a workflow can
    # force assignment before validation when it needs the number earlier.
    #
    # @return [String] the assigned number
    def generate_number
      return number if number.present?

      generator = self.class.number_generator(store: number_store)

      MAX_ATTEMPTS.times do
        candidate = generator.generate(self)
        next if candidate.blank?

        unless number_taken?(candidate)
          @number_generated = true
          return self.number = candidate
        end
      end

      raise GenerationError,
            "#{self.class.name} could not generate a unique number after " \
            "#{MAX_ATTEMPTS} attempts using #{generator.class.name}"
    end

    # The store whose number settings apply. Most numbered models belong to a
    # store directly; stock transfers reach one through their destination
    # location. Falls back to the current store so a numbered model added
    # later works without teaching this concern about it.
    #
    # @return [Spree::Store, nil]
    def number_store
      return store if respond_to?(:store) && store.present?

      Spree::Current.store
    end

    private

    # Advisory only — a concurrent writer can take the number between this
    # check and the insert, which is what the unique-index rescue below is
    # for. Unscoped because the index is global.
    def number_taken?(candidate)
      self.class.unscoped.exists?(number: candidate)
    end

    # Last line of defence. The pre-check and the uniqueness validation both
    # read committed rows, so neither can see a number another writer commits
    # in the instant between the check and this insert — only the index can.
    #
    # The insert runs in a savepoint because a constraint violation poisons
    # the surrounding PostgreSQL transaction: without one, the regenerate
    # queries below would themselves die with PG::InFailedSqlTransaction
    # instead of recovering. Only creates whose number this concern generated
    # pay for the savepoint — caller-supplied numbers should surface their
    # collision, and updates never touch the number.
    #
    # Regenerate and retry once; a second collision is a real problem worth
    # surfacing rather than looping on.
    def create_or_update(**, &block)
      return super unless new_record? && @number_generated

      begin
        self.class.transaction(requires_new: true) { super }
      rescue ActiveRecord::RecordNotUnique => error
        raise error if @number_regenerated || !number_collision?(error)

        @number_regenerated = true
        self.number = nil
        generate_number
        retry
      end
    end

    def number_collision?(error)
      error.message.to_s.downcase.include?('number')
    end
  end
end
