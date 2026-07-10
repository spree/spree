module Spree
  module Stores
    # Registry of the Getting Started onboarding tasks shown on the admin
    # dashboard. Defaults are registered in
    # `config/initializers/spree_store_setup_tasks.rb`; extensions and host
    # apps can add or remove tasks at boot:
    #
    #   Rails.application.config.after_initialize do
    #     Spree.store_setup_tasks.add :connect_stripe,
    #       position: 25,
    #       done: ->(store) { store.payment_methods.active.exists?(type: 'Spree::PaymentMethod::Stripe') }
    #
    #     Spree.store_setup_tasks.remove :setup_taxes_collection
    #   end
    #
    # Each task renders the partial `spree/admin/dashboard/setup_tasks/_<key>`
    # with a `done:` local and is titled by the `admin.store_setup_tasks.<key>`
    # translation — both overridable per task via `partial:` and `label:`.
    class SetupTasks
      class Task
        attr_reader :key, :position

        def initialize(key, position:, done:, if: nil, partial: nil, label: nil)
          raise ArgumentError, "done: must respond to #call" unless done.respond_to?(:call)

          @key = key.to_sym
          @position = position
          @done = done
          @if = binding.local_variable_get(:if)
          @partial = partial
          @label = label
        end

        # @param store [Spree::Store]
        # @return [Boolean] whether the merchant has completed this task
        def done?(store)
          !!@done.call(store)
        end

        # @param store [Spree::Store]
        # @return [Boolean] whether the task applies to this store at all
        def available?(store)
          @if.nil? || !!@if.call(store)
        end

        def partial
          @partial || "spree/admin/dashboard/setup_tasks/#{key}"
        end

        def label_key
          @label || "admin.store_setup_tasks.#{key}"
        end
      end

      def initialize
        @tasks = {}
      end

      # Registers a task (replacing any existing task with the same key).
      #
      # @param key [Symbol] identifies the task; also names its partial and translation
      # @param position [Integer] sort order on the Getting Started page
      # @param done [#call] receives the store, returns whether the task is complete
      # @param options [Hash] optional :if (per-store visibility callable),
      #   :partial and :label overrides
      # @return [Task]
      def add(key, position:, done:, **options)
        key = key.to_sym
        @tasks[key] = Task.new(key, position: position, done: done, **options)
      end

      # @param key [Symbol]
      # @return [Task, nil] the removed task
      def remove(key)
        @tasks.delete(key.to_sym)
      end

      def find(key)
        @tasks[key.to_sym]
      end

      def exists?(key)
        @tasks.key?(key.to_sym)
      end

      # @return [Array<Task>] all tasks sorted by position
      def tasks
        @tasks.values.sort_by(&:position)
      end

      # @param store [Spree::Store]
      # @return [Array<Task>] the tasks applicable to the given store, sorted by position
      def for(store)
        tasks.select { |task| task.available?(store) }
      end
    end
  end
end
