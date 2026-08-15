module Spree
  # Base class for operator-run data work — backfills, reindexes, bulk
  # corrections, the fix after a bad import (docs/plans/6.0-maintenance-tasks.md).
  #
  # A task is reviewed, deployed code rather than a console paste: it declares
  # its parameters, walks a stable-ordered collection, and processes one record
  # at a time. The runner (Spree::MaintenanceTasks::RunJob) supplies batching,
  # checkpointing, pause/resume/cancel and the audit row, so a task body says
  # only what it does.
  #
  #   class Spree::MaintenanceTasks::BackfillOrderMarkets < Spree::MaintenanceTask
  #     description 'Assign a market to orders placed before markets existed'
  #     supports_dry_run
  #
  #     attribute :market_id, :string
  #     validates :market_id, presence: true
  #
  #     def collection
  #       Spree::Order.where(market_id: nil).order(:id)
  #     end
  #
  #     def process(order)
  #       return tally(:would_update) if dry_run?
  #
  #       order.update_columns(market_id: market_id)
  #       tally(:updated)
  #     end
  #   end
  #
  # Tasks are only runnable once registered — `Spree.maintenance_tasks` holds
  # class names, appended from an engine or host initializer. A class that
  # merely exists under app/maintenance_tasks is not an operator-visible task.
  class MaintenanceTask
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Never rendered back to a caller. Masked arguments are still persisted —
    # a run has to be reproducible — but the API, dashboard and CLI all read
    # through MaintenanceTaskRun#display_arguments.
    MASKED_VALUE = '••••••••'.freeze

    DEFAULT_BATCH_SIZE = 100
    DEFAULT_MAX_RUN_TIME = 5.minutes

    class_attribute :task_description, instance_writer: false
    class_attribute :dry_run_supported, instance_writer: false, default: false
    class_attribute :collection_kind, instance_writer: false, default: :relation
    class_attribute :batch_size, instance_writer: false, default: DEFAULT_BATCH_SIZE
    class_attribute :run_time_limit, instance_writer: false, default: DEFAULT_MAX_RUN_TIME
    class_attribute :masked_attributes, instance_writer: false, default: [].freeze
    class_attribute :throttle_conditions, instance_writer: false, default: [].freeze
    class_attribute :reported_errors, instance_writer: false, default: [].freeze
    class_attribute :preconditions, instance_writer: false, default: [].freeze

    attr_accessor :run

    class << self
      # @param text [String] shown in the task list. Pass a translation key
      #   relative to the `spree.` scope (`maintenance_tasks.my_task.description`)
      #   to localize it; anything that does not resolve is shown as written,
      #   so a plain sentence works too.
      def description(text = nil)
        return task_description if text.nil?

        self.task_description = text
      end

      # Declares that `process` honors `dry_run?`. Without it the dashboard
      # offers no preview toggle — the runner never fakes one by rolling a
      # transaction back, which would silently lie about external calls,
      # enqueued jobs and cache writes.
      def supports_dry_run
        self.dry_run_supported = true
      end

      # The task performs a single operation instead of iterating; `process`
      # is called once with no argument.
      def no_collection
        self.collection_kind = :none
      end

      def collection_batch_size(size)
        self.batch_size = size
      end

      # How long one execution may run before the runner checkpoints and
      # re-enqueues itself, so a long task cannot hold a worker indefinitely.
      def max_run_time(duration)
        self.run_time_limit = duration
      end

      # Hides an attribute's value everywhere a run is displayed.
      def mask_attribute(*names)
        self.masked_attributes = (masked_attributes + names.map(&:to_s)).uniq.freeze
      end

      # Pauses work while the block is true — replica lag, queue depth, a
      # third-party rate limit. Evaluated before each batch.
      #
      # @param backoff [ActiveSupport::Duration, Proc] how long to wait
      def throttle_on(backoff: 30.seconds, &condition)
        self.throttle_conditions = (throttle_conditions + [{ backoff: backoff, condition: condition }]).freeze
      end

      # Rescues a per-record error, reports it, and carries on with the next
      # record instead of failing the whole run.
      def report_on(*error_classes, severity: :error)
        self.reported_errors = (reported_errors + error_classes.map { |klass| { class: klass, severity: severity } }).freeze
      end

      # Checked before a run is created; a false block is a 422 rather than a
      # run that fails on its first record. Use for "the migration that adds
      # this column has not been deployed yet".
      def precondition(message, &block)
        self.preconditions = (preconditions + [{ message: message, block: block }]).freeze
      end

      # @return [Array<Class>] registered task classes, sorted by name
      def registered_classes
        Spree.maintenance_tasks.filter_map do |entry|
          entry.is_a?(Class) ? entry : entry.to_s.safe_constantize
        end.uniq.sort_by(&:name)
      end

      # @param name [String] a task class name
      # @return [Class, nil] nil when the name is not registered — an
      #   unregistered task is never runnable, so the runner and the API can
      #   treat nil as "no such task" without a second check
      def find_registered(name)
        return nil if name.blank?

        registered_classes.find { |klass| klass.name == name.to_s }
      end

      # The parameter schema the dashboard renders a form from. Mirrors the
      # shape PreferenceSchema emits for integrations, so both surfaces share
      # one renderer.
      def parameters_schema
        attribute_types.map do |name, type|
          {
            name: name,
            type: schema_type_for(type),
            required: required_attribute?(name),
            options: attribute_options(name),
            masked: masked_attributes.include?(name),
            default: _default_attributes[name]&.value_before_type_cast
          }
        end
      end

      def resolved_description
        return nil if task_description.blank?

        translated = Spree.t(task_description, default: task_description)
        translated.is_a?(String) ? translated : task_description
      end

      private

      def schema_type_for(type)
        case type.type
        when :integer then 'integer'
        when :decimal, :float then 'decimal'
        when :boolean then 'boolean'
        when :date then 'date'
        when :datetime then 'datetime'
        else 'string'
        end
      end

      def required_attribute?(name)
        validators_on(name).any? { |validator| validator.is_a?(ActiveModel::Validations::PresenceValidator) }
      end

      # An inclusion validator is what turns a parameter into a select in the
      # dashboard rather than a free-text field.
      def attribute_options(name)
        validator = validators_on(name).find { |candidate| candidate.is_a?(ActiveModel::Validations::InclusionValidator) }
        return nil if validator.nil?

        values = validator.options[:in] || validator.options[:within]
        values.respond_to?(:call) ? nil : Array(values)
      end
    end

    # The records to walk. Return a relation with an explicit, stable order —
    # the cursor is a value from that ordering, so an unordered relation would
    # resume in the wrong place. Arrays are walked by index.
    #
    # @return [ActiveRecord::Relation, Array, nil]
    def collection
      raise NotImplementedError, "#{self.class.name} must implement #collection or declare `no_collection`"
    end

    # @param item [Object] one record from the collection; omitted for
    #   `no_collection` tasks
    def process(item = nil)
      raise NotImplementedError, "#{self.class.name} must implement #process"
    end

    # Total records, for the progress bar. Return nil when counting is more
    # expensive than the work itself — the run then reports ticks only.
    #
    # @return [Integer, nil]
    def count
      return nil if no_collection?

      items = collection
      items.respond_to?(:count) ? items.count : nil
    end

    def no_collection?
      self.class.collection_kind == :none
    end

    def dry_run?
      run&.dry_run? || false
    end

    # The store the operator was acting in. Tasks that must run per store take
    # the store as an explicit parameter instead — this is context, not scope.
    def store
      run&.store
    end

    # Records a counter shown on the run page: what was updated, skipped, or
    # would have changed in a dry run.
    def tally(key, by = 1)
      @tallies ||= Hash.new(0)
      @tallies[key.to_s] += by
    end

    def tallies
      @tallies ||= Hash.new(0)
    end

    # The cursor value for a record. Defaults to the primary key, matching the
    # default `order(:id)` walk; override together with `collection` when the
    # task orders by something else.
    def cursor_for(item)
      item.respond_to?(:id) ? item.id.to_s : item.to_s
    end

    def after_start; end
    def after_pause; end
    def after_interrupt; end
    def after_cancel; end
    def after_complete; end
    def after_error(_error); end
  end
end
