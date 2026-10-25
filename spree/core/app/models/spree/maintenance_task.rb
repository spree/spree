module Spree
  # Base class for the data work an upgrade runs: one step of an upgrade
  # manifest (docs/plans/6.0-maintenance-tasks.md).
  #
  # A task walks a stable-ordered collection and processes one record at a
  # time. The runner (Spree::MaintenanceTasks::RunJob) supplies batching,
  # checkpointing, pause/resume/cancel and the audit row, so a task body says
  # only what it does.
  #
  #   class Spree::MaintenanceTasks::Upgrade::BackfillOrderMarkets < Spree::MaintenanceTask
  #     supports_dry_run
  #
  #     def collection
  #       Spree::Order.where(market_id: nil).order(:id)
  #     end
  #
  #     def process(order)
  #       return tally(:would_update) if dry_run?
  #
  #       order.update_columns(market_id: order.store.default_market.id)
  #       tally(:updated)
  #     end
  #   end
  #
  # A manifest step names its task class, which registers it in
  # `Spree.maintenance_tasks`; nothing else is runnable.
  class MaintenanceTask
    include ActiveModel::Model
    include ActiveModel::Attributes
    extend Spree::ApiTyped

    # A rake body that stopped itself with `abort`.
    class RakeTaskAborted < StandardError; end

    DEFAULT_BATCH_SIZE = 100

    # How long one execution may run before the runner checkpoints and
    # re-enqueues itself, so a long step cannot hold a worker indefinitely.
    MAX_RUN_TIME = 5.minutes

    class_attribute :dry_run_supported, instance_writer: false, default: false
    class_attribute :collection_kind, instance_writer: false, default: :relation
    class_attribute :batch_size, instance_writer: false, default: DEFAULT_BATCH_SIZE

    attr_accessor :run

    class << self
      # Declares that `process` honors `dry_run?`. The runner never fakes a
      # dry run by rolling a transaction back, which would silently lie about
      # external calls, enqueued jobs and cache writes.
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

      # The registered task an API caller names. Matches the short name only,
      # so a Ruby class name arriving over the API is an unknown task.
      #
      # @param api_type [String] e.g. "capture_methods"
      # @return [Class, nil]
      def find_by_api_type(api_type)
        Spree::ApiTyped.find(Spree.maintenance_tasks, api_type)
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
    # default `order(:id)` walk.
    def cursor_for(item)
      item.respond_to?(:id) ? item.id.to_s : item.to_s
    end

    # Rake tasks are defined by the Rakefile, which a web process never loads —
    # a task fired from the dashboard has to load the engine's tasks itself.
    #
    # Loads the one file that defines the task, and only when it is not already
    # defined. Both halves matter: re-loading a .rake file APPENDS its block to
    # a task that already exists, so a second load makes that task run twice,
    # and loading every file would do that to every task in the engine. The
    # symptom is invisible until something counts what it did.
    #
    # @param task_name [String] the rake task about to be invoked
    def load_engine_rake_tasks(task_name)
      require 'rake'

      return if ::Rake::Task.task_defined?(task_name)

      ::Rake::Task.define_task(:environment) unless ::Rake::Task.task_defined?(:environment)

      path = rake_file_defining(task_name)
      load(path) if path
    end

    # Runs an engine rake task as part of this task.
    #
    # Rake bodies stop themselves with `abort`, which raises SystemExit — not
    # an error the runner records. Left alone it would end the whole process
    # from the command line and, in a worker, leave the run marked running
    # with nothing to finish it.
    #
    # @param task_name [String]
    # @raise [RakeTaskAborted] carrying the body's own message
    def invoke_rake_task(task_name)
      load_engine_rake_tasks(task_name)

      task = ::Rake::Task[task_name]
      task.reenable
      task.invoke
    rescue SystemExit => e
      raise RakeTaskAborted, e.message
    end

    # Finds the file that defines a task by reading the files rather than
    # loading them: loading a .rake file to discover whether it is the right
    # one would append its blocks to every task it defines, which is the very
    # duplication this avoids.
    #
    # Searches every engine and the host application, since a step may ship in
    # an extension gem. When two files define the same task name, the one
    # that also declares the task's namespaces wins.
    #
    # @return [String, nil]
    def rake_file_defining(task_name)
      *namespaces, leaf = task_name.split(':')
      candidates = rake_files.select do |path|
        File.read(path).match?(/^\s*(?:desc\s.*\n\s*)?task\s+:?["']?#{Regexp.escape(leaf)}["']?\b/)
      end

      candidates.find do |path|
        source = File.read(path)
        namespaces.all? { |name| source.match?(/namespace\s+:?["']?#{Regexp.escape(name)}["']?\b/) }
      end || candidates.first
    end

    def rake_files
      roots = Rails.application.railties.grep(Rails::Engine).map(&:root) + [Rails.root]
      roots.uniq.flat_map { |root| Dir.glob(File.join(root, 'lib/tasks/**/*.rake')).sort }
    end

    # Called once the last record has been processed, before the run is
    # marked succeeded — for a summary tally of what the walk left alone.
    def after_complete; end
  end
end
