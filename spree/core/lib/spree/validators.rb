module Spree
  # Registry of extra validator classes run against a model on top of its own
  # validations. Addresses are the one model that ships with it, because
  # address rules are regional and business-specific — phone formats, VAT
  # numbers, address verification — and a host needs to add and remove them
  # without reopening the model.
  #
  #   Spree.validators.addresses.register(MyStore::PostBoxValidator)
  #   Spree.validators.addresses.unregister(Spree::Addresses::PhoneValidator)
  #
  # Register from `config.to_prepare` (not an initializer) when the validator
  # is your own class: the set holds classes, so a reloadable constant
  # registered once at boot would go stale on the next reload.
  #
  # For rules that veto a whole flow rather than shape a record, use a
  # workflow :validate hook instead (see Spree::Hooks).
  class Validators
    # One named set of validator classes. Subclasses Array so the historical
    # `Spree.validators.addresses` — which was a plain array of classes, and
    # which hosts may already read, map or push onto — keeps behaving exactly
    # as it did; register/unregister are the documented API on top.
    class Set < Array
      def initialize(entries = [])
        super()
        replace(entries)
      end

      # @param validator [Class, String] class responding to the
      #   ActiveModel::Validator contract
      # @return [Class] the registered validator
      def register(validator)
        resolved = resolve(validator)
        push(resolved) unless include?(resolved)
        resolved
      end

      # @param validator [Class, String]
      # @return [Class, nil] the removed validator, nil when not registered
      def unregister(validator)
        delete(resolve(validator))
      end

      def replace(entries)
        super(Array(entries).map { |entry| resolve(entry) })
      end

      private

      def resolve(validator)
        validator.is_a?(String) || validator.is_a?(Symbol) ? validator.to_s.constantize : validator
      end
    end

    def initialize
      @sets = Hash.new { |sets, name| sets[name] = Set.new }
    end

    def [](name)
      @sets[name.to_sym]
    end

    def []=(name, entries)
      @sets[name.to_sym] = Set.new(entries)
    end

    def addresses
      self[:addresses]
    end

    def addresses=(entries)
      self[:addresses] = entries
    end
  end
end
