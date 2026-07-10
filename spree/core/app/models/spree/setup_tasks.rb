module Spree
  # Registry of onboarding tasks for a given subject type. `Spree.store_setup_tasks`
  # holds the Getting Started checklist evaluated against a store; future
  # registries (e.g. vendor onboarding) instantiate the same class against
  # their own subject. Defaults are registered in
  # `config/initializers/spree_store_setup_tasks.rb`; extensions and host apps
  # can add or remove tasks at boot:
  #
  #   Rails.application.config.after_initialize do
  #     Spree.store_setup_tasks.add :connect_stripe,
  #       position: 25,
  #       done: ->(store) { store.payment_methods.active.exists?(type: 'Spree::PaymentMethod::Stripe') }
  #
  #     Spree.store_setup_tasks.remove :setup_taxes_collection
  #   end
  #
  # The registry holds domain data only — each frontend maps task keys to its
  # own presentation: the legacy admin renders the
  # `spree/admin/dashboard/setup_tasks/_<key>` partial titled by the
  # `admin.store_setup_tasks.<key>` translation (both resolved across engine
  # paths, so extensions ship theirs by convention), and the React dashboard
  # consumes tasks as {Spree::SetupTask} records via the Admin API.
  class SetupTasks
    class Definition
      attr_reader :key, :position

      def initialize(key, position:, done:, if: nil)
        raise ArgumentError, "done: must respond to #call" unless done.respond_to?(:call)

        @key = key.to_sym
        @position = position
        @done = done
        @if = binding.local_variable_get(:if)
      end

      # @param subject [Object] the record the checklist belongs to (e.g. a store)
      # @return [Boolean] whether the task is complete
      def done?(subject)
        !!@done.call(subject)
      end

      # @param subject [Object] the record the checklist belongs to
      # @return [Boolean] whether the task applies to this subject at all
      def available?(subject)
        @if.nil? || !!@if.call(subject)
      end
    end

    def initialize
      @tasks = {}
    end

    # Registers a task (replacing any existing task with the same key).
    #
    # @param key [Symbol] identifies the task; frontends derive presentation from it
    # @param position [Integer] sort order in the checklist
    # @param done [#call] receives the subject, returns whether the task is complete
    # @param options [Hash] optional :if (per-subject visibility callable)
    # @return [Definition]
    def add(key, position:, done:, **options)
      key = key.to_sym
      @tasks[key] = Definition.new(key, position: position, done: done, **options)
    end

    # @param key [Symbol]
    # @return [Definition, nil] the removed task
    def remove(key)
      @tasks.delete(key.to_sym)
    end

    def find(key)
      @tasks[key.to_sym]
    end

    def exists?(key)
      @tasks.key?(key.to_sym)
    end

    # @return [Array<Definition>] all tasks sorted by position
    def tasks
      @tasks.values.sort_by(&:position)
    end

    # @param subject [Object] the record the checklist belongs to (e.g. a store)
    # @return [Array<Definition>] the tasks applicable to the given subject, sorted by position
    def for(subject)
      tasks.select { |task| task.available?(subject) }
    end
  end
end
