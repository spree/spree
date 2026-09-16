module Spree
  module AgentTools
    # One agent tool per exposed workflow.
    #
    # Every back-office write already goes through a workflow, so there is
    # nothing to hand-write: the allowlist names a `Spree::Dependencies` key
    # and a permission, {WorkflowSchema} reads the argument contract off the
    # workflow's own `perform`, and this class resolves the arguments, injects
    # the principal, takes the lock the controller takes and shapes the result.
    #
    # Generated classes are anonymous subclasses cached per dependency key, so
    # a host app that swaps `Spree.order_cancel_workflow` for its own class
    # keeps the tool and gets the replacement's schema.
    class WorkflowTool < Spree::AgentTool
      class_attribute :dependency_key, instance_accessor: false
      class_attribute :schema_except, instance_accessor: false, default: [].freeze
      class_attribute :summary_override, instance_accessor: false

      class << self
        # Builds (and caches) the tool class for one exposed workflow.
        #
        # @param dependency_key [Symbol] a `Spree::Dependencies` key
        # @param permission [String] the `write_*` key gating it
        # @param except [Array<Symbol>] parameters to hide
        # @param summary [#call, nil] overrides the generated confirmation line
        # @return [Class<WorkflowTool>, nil] nil when the key does not resolve
        def for(dependency_key, permission:, except: [], summary: nil)
          workflow_class = resolve_workflow(dependency_key)
          return if workflow_class.nil?

          cache_key = [dependency_key, workflow_class.name, permission, except, summary.object_id]
          cache[cache_key] ||= build(dependency_key, workflow_class, permission, except, summary)
        end

        # @return [void]
        def clear_cache!
          @cache = {}
        end

        # The tool name for a dependency key: the workflow's dotted identity
        # with dots as underscores, because MCP names allow only letters,
        # digits, underscore and hyphen.
        #
        # @param workflow_class [Class]
        # @return [String]
        def tool_name_for(workflow_class)
          workflow_class.workflow_key.tr('.', '_')
        end

        # @return [Class, nil]
        def resolve_workflow(dependency_key)
          Spree.public_send(dependency_key)
        rescue NoMethodError, NameError
          nil
        end

        # The workflow's own leading comment, first paragraph — what the class
        # says it does, in the author's words rather than a second description
        # kept in step by hand.
        #
        # @param workflow_class [Class]
        # @return [String]
        def description_for(workflow_class)
          paragraph = leading_comment(workflow_class)
          return "Runs the #{workflow_class.workflow_key.tr('.', ' ')} workflow." if paragraph.blank?

          paragraph
        end

        private

        def cache
          @cache ||= {}
        end

        def build(dependency_key, workflow_class, permission_key, except, summary)
          derived_schema = WorkflowSchema.new(workflow_class, except: except)
          derived_name = tool_name_for(workflow_class)
          derived_description = description_for(workflow_class)

          Class.new(self) do
            self.dependency_key = dependency_key
            self.schema_except = except.freeze
            self.summary_override = summary

            tool_name derived_name
            description derived_description
            permission permission_key
            mutating!

            derived_schema.parameters.each do |parameter|
              param parameter[:name],
                    type: parameter[:json_type].to_sym,
                    description: parameter[:description],
                    required: parameter[:required]
            end
          end
        end

        def leading_comment(workflow_class)
          location = Object.const_source_location(workflow_class.name)
          return if location.nil?

          file, line = location
          return unless file && File.exist?(file)

          lines = File.readlines(file)
          comment = []
          index = line - 2
          while index >= 0 && lines[index].strip.start_with?('#')
            comment.unshift(lines[index].strip.delete_prefix('#').strip)
            index -= 1
          end
          # First paragraph only — the rest is design rationale for readers of
          # the class, not for a model choosing between tools.
          comment.take_while(&:present?).join(' ').presence
        end
      end

      # @return [Class] the workflow this tool runs, resolved now so a host
      #   app's replacement is picked up without a restart
      def workflow_class
        self.class.resolve_workflow(self.class.dependency_key)
      end

      # @return [WorkflowSchema]
      def schema
        @schema ||= WorkflowSchema.new(workflow_class, except: self.class.schema_except)
      end

      # Runs the workflow with the caller's arguments.
      #
      # Model-typed arguments arrive as prefixed ids and are resolved through
      # the resource map under the context's store, so another store's id is
      # simply not found. Principal parameters are never accepted from the
      # caller — they are filled from the authenticated principal.
      #
      # @return [Hash] the result handed back to the model
      def call(**arguments)
        resolved = resolve_arguments(arguments)
        return resolved if resolved.is_a?(Hash) && resolved[:error]

        keywords = resolved.merge(principal_arguments).merge(context_arguments)

        run(keywords)
      rescue ArgumentError => e
        { error: e.message }
      end

      # One line saying what this tool did, for the client's confirmation
      # prompt and the assistant's approval card.
      #
      # @param arguments [Hash]
      # @return [String]
      def summary(arguments)
        return self.class.summary_override.call(context, arguments) if self.class.summary_override

        action = workflow_class.workflow_key.tr('.', ' ').humanize
        subject = subject_summary(arguments)
        [action, subject].compact.join(' ')
      end

      private

      def run(keywords)
        subject = keywords.values.find { |value| value.is_a?(ActiveRecord::Base) }

        result = with_subject_lock(subject) { workflow_class.call(**keywords) }

        if result.success?
          { summary: summary(keywords), record: record_result(result.value) }
        else
          { error: error_text(result) }
        end
      end

      # The same row lock the admin controllers take for an order-subject
      # workflow. Taken generically: whichever record the workflow is acting
      # on is the one that must not change underneath it.
      def with_subject_lock(subject, &)
        return yield unless subject.respond_to?(:with_lock) && subject.persisted?

        subject.with_lock(&)
      end

      def record_result(value)
        return unless value.is_a?(ActiveRecord::Base)

        entry = ResourceMap.all.find { |candidate| value.is_a?(candidate.model_class) }
        return { id: value.try(:prefixed_id) } if entry.nil?

        RecordSummary.call(entry: entry, record: value)
      end

      # The workflow's own refusal, in its own words, so the model can correct
      # itself instead of retrying blind.
      def error_text(result)
        error = result.error
        errors = error.respond_to?(:value) ? error.value : error

        return errors.full_messages.to_sentence if errors.respond_to?(:full_messages) && errors.any?
        return error.to_s if error.present?

        'The workflow refused the change.'
      end

      def principal_arguments
        schema.principal_parameters.index_with { context.principal }
      end

      # Tenancy comes from the credential, never from a parameter.
      def context_arguments
        schema.context_parameters.index_with { context.store }
      end

      # Turns the caller's JSON arguments into what `perform` expects,
      # resolving every model-typed parameter from its prefixed id.
      #
      # @return [Hash, Hash{Symbol => String}] keywords, or an `{error:}` result
      def resolve_arguments(arguments)
        resolved = {}

        schema.parameters.each do |parameter|
          name = parameter[:name]
          next unless arguments.key?(name)

          value = arguments[name]
          next if value.nil?

          if parameter[:model_name]
            record = find_record(parameter[:model_name], value)
            return { error: "No #{parameter[:model_name].demodulize.underscore.humanize.downcase} found for #{name} #{value.inspect}." } if record.nil?

            resolved[name] = record
          else
            resolved[name] = value
          end
        end

        resolved
      end

      # Resolves a prefixed id within the caller's store, through the resource
      # map — so tenancy is answered the same way every read is.
      #
      # A model the map does not hold is one with no store scoping of its own
      # (a certificate belongs to a company, a submission to a seller). Those
      # resolve through the mapped parent, so the id still has to belong to
      # this store; a model with neither is not resolvable and the caller is
      # told so rather than being handed another store's record.
      def find_record(model_name, value)
        relation = store_scoped_relation(model_name)
        return if relation.nil?

        relation.find_by_prefix_id(value)
      rescue StandardError
        nil
      end

      def store_scoped_relation(model_name)
        entry = ResourceMap.all.find { |candidate| candidate.model_name == model_name }
        return entry.scope_for(context) if entry

        parent_scoped_relation(model_name.constantize)
      end

      # Narrows an unscoped model through whichever of its parents the map
      # knows, so `certificate` is looked up among this store's companies'
      # certificates rather than every store's.
      def parent_scoped_relation(model_class)
        model_class.reflect_on_all_associations(:belongs_to).each do |association|
          next if association.polymorphic?

          entry = ResourceMap.all.find { |candidate| candidate.model_name == association.klass.name }
          next if entry.nil?

          return model_class.where(association.foreign_key => entry.scope_for(context).select(:id))
        end

        nil
      end

      def subject_summary(arguments)
        record = arguments.values.find { |value| value.is_a?(ActiveRecord::Base) }
        return if record.nil?

        record.try(:number) || record.try(:name) || record.try(:prefixed_id)
      end
    end
  end
end
