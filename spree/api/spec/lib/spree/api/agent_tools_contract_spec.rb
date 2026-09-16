require 'spec_helper'

# The Admin API's controllers are the reference wiring for what an agent may
# do: they define which workflow writes a resource, which permission gates it,
# and how a request becomes workflow keywords. These examples keep the agent
# catalog honest against them, so a new admin endpoint cannot quietly arrive
# without an agent deciding what to do about it.
#
# See docs/plans/6.0-mcp-server.md.
RSpec.describe 'agent tool contract' do
  # Every `Spree.<key>_workflow` an admin controller calls, found by reading
  # the controller sources — the same way a reviewer would.
  def workflows_invoked_by_admin_controllers
    root = Spree::Api::Engine.root.join('app', 'controllers', 'spree', 'api', 'v3', 'admin')

    Dir.glob(root.join('**', '*.rb')).flat_map do |path|
      File.read(path).scan(/Spree\.([a-z_]+_workflow)\b/).flatten
    end.uniq.map(&:to_sym).sort
  end

  # Whether an unmapped model reaches the store through a parent the map does
  # hold, which is how Spree::AgentTools::WorkflowTool resolves it.
  def mapped_parent?(model_name, mapped)
    model_name.constantize.reflect_on_all_associations(:belongs_to).any? do |association|
      !association.polymorphic? && mapped.include?(association.klass.name)
    end
  rescue StandardError
    false
  end

  # Resource keys whose controller guards against a caller granting authority
  # it does not hold, which the derivation deliberately makes read-only.
  def authority_keys
    Spree::Api::AgentResourceMap.controllers.filter_map do |controller|
      next unless controller.include?(Spree::Api::V3::Admin::RoleGrantGuard)

      model = Spree::Api::AgentResourceMap.send(:safely, controller.allocate, :model_class)
      model && model.model_name.element.pluralize
    end
  end

  # Resource keys served by more than one admin controller under different
  # scopes, which the derivation deliberately makes read-only.
  def contested_keys
    by_key = Spree::Api::AgentResourceMap.controllers.each_with_object(Hash.new { |h, k| h[k] = [] }) do |controller, result|
      model = Spree::Api::AgentResourceMap.send(:safely, controller.allocate, :model_class)
      next if model.nil? || controller._scoped_resource.blank?

      result[model.model_name.element.pluralize] << controller._scoped_resource
    end

    by_key.select { |_key, scopes| scopes.uniq.size > 1 }.keys
  end

  let(:catalog) { Spree::AgentTools::DefaultCatalog }

  describe 'the workflow allowlist' do
    it 'accounts for every workflow an admin controller invokes' do
      invoked = workflows_invoked_by_admin_controllers
      accounted = catalog::WORKFLOWS.keys + catalog::EXCLUDED_WORKFLOWS.keys

      unaccounted = invoked - accounted

      expect(unaccounted).to be_empty, <<~MESSAGE
        These workflows are called by an admin controller but are neither exposed
        as agent tools nor excluded with a reason:

          #{unaccounted.join("\n  ")}

        Add each to Spree::AgentTools::DefaultCatalog::WORKFLOWS with the write
        permission its controller declares, or to EXCLUDED_WORKFLOWS saying why
        an agent must not run it.
      MESSAGE
    end

    it 'exposes nothing an admin controller does not invoke' do
      # A workflow no controller reaches has no reference wiring: nothing says
      # how a request becomes its keywords, or which permission gates it.
      stray = catalog::WORKFLOWS.keys - workflows_invoked_by_admin_controllers -
              # The products status workflows are reached through the products
              # controller's own status actions, which call them by a
              # dynamically built key rather than a literal.
              %i[product_activate_workflow product_draft_workflow product_archive_workflow]

      expect(stray).to be_empty
    end

    it 'gives every exclusion a reason' do
      expect(catalog::EXCLUDED_WORKFLOWS.values).to all(be_present)
    end

    it 'names a permission the catalog knows for every exposed workflow' do
      unknown = catalog::WORKFLOWS.filter_map do |key, options|
        permission = options.is_a?(Hash) ? options[:permission] : options
        "#{key} => #{permission}" unless Spree.permissions.key?(permission)
      end

      expect(unknown).to be_empty
    end

    it 'gates every exposed workflow with a write permission' do
      reads = catalog::WORKFLOWS.filter_map do |key, options|
        permission = options.is_a?(Hash) ? options[:permission] : options
        key unless permission.start_with?('write_')
      end

      expect(reads).to be_empty
    end

    it 'resolves every exposed workflow to a class' do
      unresolved = catalog::WORKFLOWS.keys.reject { |key| Spree.public_send(key).is_a?(Class) }

      expect(unresolved).to be_empty
    end
  end

  describe 'schema derivation' do
    it 'derives a schema for every exposed workflow' do
      failures = catalog::WORKFLOWS.filter_map do |key, options|
        options = { permission: options } unless options.is_a?(Hash)
        Spree::AgentTools::WorkflowSchema.new(Spree.public_send(key), except: Array(options[:except])).parameters
        nil
      rescue StandardError => e
        "#{key}: #{e.message}"
      end

      expect(failures).to be_empty, <<~MESSAGE
        Every parameter of an exposed workflow needs a YARD `@param` with a type,
        because the tool's schema is derived from it:

          #{failures.join("\n  ")}
      MESSAGE
    end

    # A prefixed id can only be turned into a record under the caller's store.
    # The map answers that directly for a store-scoped model; a model scoped
    # through its parent (a certificate through its company) is resolved
    # through that parent. A model with neither has no tenancy answer at all,
    # and must not be a parameter of an exposed workflow.
    it 'can resolve every record parameter within a store' do
      Spree::Api::AgentResourceMap.install
      mapped = Spree::AgentTools::ResourceMap.all.map(&:model_name)

      unresolvable = catalog::WORKFLOWS.flat_map do |key, options|
        options = { permission: options } unless options.is_a?(Hash)
        schema = Spree::AgentTools::WorkflowSchema.new(Spree.public_send(key), except: Array(options[:except]))

        schema.parameters.filter_map do |parameter|
          model_name = parameter[:model_name]
          next if model_name.blank? || mapped.include?(model_name)
          next if mapped_parent?(model_name, mapped)

          "#{key}.#{parameter[:name]} => #{model_name}"
        end
      end

      expect(unresolvable).to be_empty, <<~MESSAGE
        A record parameter is filled from a prefixed id, which is only safe when
        the record can be narrowed to the caller's store — through the resource
        map, or through a parent the map holds. These can be narrowed by neither:

          #{unresolvable.join("\n  ")}
      MESSAGE
    end

    # Asserted against the naming convention rather than against the injected
    # list, which would be circular: a parameter is only offered because it is
    # not on that list, so comparing the two can never fail. A keyword that
    # reads as "who did this" and is still offered is the bug worth catching.
    it 'never offers a parameter that names who acted' do
      # `<verb>ed_by` is the shape that names a person. A `cancel_by` is a
      # date the merchant sets, not an actor, so the participle matters.
      actor_shaped = /\A(\w+ed_by|created_by|canceler|approver|reviewer|refunder|requester)\z/

      offered = catalog::WORKFLOWS.flat_map do |key, options|
        options = { permission: options } unless options.is_a?(Hash)
        schema = Spree::AgentTools::WorkflowSchema.new(Spree.public_send(key), except: Array(options[:except]))

        schema.parameters.filter_map do |parameter|
          "#{key}.#{parameter[:name]}" if parameter[:name].to_s.match?(actor_shaped)
        end
      end

      expect(offered).to be_empty, <<~MESSAGE
        These parameters name who performed the action, and the answer is the
        authenticated principal — never something a caller may claim:

          #{offered.join("\n  ")}

        Declare the association with `acted_by` so it is injected, or add the
        keyword to WorkflowSchema::UNCONVERTED_PRINCIPAL_PARAMETERS until it is.
      MESSAGE
    end

    it 'injects every actor association the acted_by registry knows' do
      declared = Spree::ActedBy.models.flat_map(&:acted_by_associations).map(&:to_sym)

      expect(Spree::AgentTools::WorkflowSchema.principal_parameter_names).to include(*declared)
    end

    it 'gives every exposed workflow a unique tool name' do
      names = catalog::WORKFLOWS.keys.map { |key| Spree::AgentTools::WorkflowTool.tool_name_for(Spree.public_send(key)) }

      expect(names).to match_array(names.uniq)
    end

    it 'gives every tool a name the protocol accepts' do
      invalid = catalog::WORKFLOWS.keys.map { |key| Spree::AgentTools::WorkflowTool.tool_name_for(Spree.public_send(key)) }.
                reject { |name| name.match?(/\A[a-zA-Z0-9_-]{1,64}\z/) }

      expect(invalid).to be_empty
    end
  end

  describe 'the derived resource map' do
    before { Spree::Api::AgentResourceMap.install }

    it 'registers every admin resource controller that serves a store-scoped model' do
      expect(Spree::AgentTools::ResourceMap.all).not_to be_empty
    end

    it 'never registers a resource whose serializer carries a credential' do
      registered = Spree::AgentTools::ResourceMap.all.map(&:model_name)

      expect(registered).not_to include(*Spree::Api::AgentResourceMap::WITHHELD_MODELS)
    end

    it 'names a permission the catalog knows for every resource' do
      unknown = Spree::AgentTools::ResourceMap.all.reject { |entry| Spree.permissions.key?(entry.permission) }

      expect(unknown.map(&:key)).to be_empty
    end

    it 'refuses generic writes for a resource written through a workflow' do
      with_workflow = Spree::AgentTools::ResourceMap.all.select do |entry|
        entry.create_workflow_key.present? || entry.update_workflow_key.present?
      end

      expect(with_workflow).not_to be_empty
      expect(with_workflow.map(&:generic_writes?).uniq).to eq([false])
    end

    it 'refuses generic writes for a resource written through a Tier 1 service' do
      service_written = Spree::AgentTools::ResourceMap.all.select do |entry|
        Spree::Api::AgentResourceMap::SERVICE_WRITTEN_MODELS.include?(entry.model_name)
      end

      expect(service_written.map(&:generic_writes?).uniq - [false]).to be_empty
    end

    it 'gives every generically writable resource a documented attribute list' do
      empty = Spree::AgentTools::ResourceMap.all.select(&:generic_writes?).
              select { |entry| entry.writable_attribute_names.empty? }

      expect(empty.map(&:key)).to be_empty, <<~MESSAGE
        These resources accept generic writes but document no writable attributes
        in docs/api-reference/admin.yaml, so an agent has nothing to fill in:

          #{empty.map(&:key).join("\n  ")}

        Regenerate the spec (bundle exec rake rswag:specs:swaggerize), or give the
        resource a write workflow.
      MESSAGE
    end

    # A model served by two controllers under different scopes has no single
    # right permission, and picking whichever sorted last would grant a key
    # holding the wider scope records the narrower one guards. So the narrower
    # wins and the resource stays read-only.
    it 'resolves a resource served under two scopes to the narrower, read-only' do
      by_model = Spree::Api::AgentResourceMap.controllers.each_with_object(Hash.new { |h, k| h[k] = [] }) do |controller, result|
        model = Spree::Api::AgentResourceMap.send(:safely, controller.allocate, :model_class)
        next if model.nil? || controller._scoped_resource.blank?

        result[model.name] << "read_#{controller._scoped_resource}"
      end

      contested = by_model.select { |_model, permissions| permissions.uniq.size > 1 }

      contested.each do |model_name, permissions|
        entry = Spree::AgentTools::ResourceMap.all.find { |candidate| candidate.model_name == model_name }
        next if entry.nil?

        expect(permissions).to include(entry.permission)
        expect(entry.generic_writes?).to be(false),
                                        "#{entry.key} is served under #{permissions.uniq.to_sentence} yet accepts generic writes"
      end
    end

    # The real guard on generic writes is the OpenAPI document, not the
    # hand-written exclusion list: a resource the Admin API does not document a
    # write body for cannot become writable, whether or not anyone remembered
    # to list it. Asserting that keeps the list belt-and-braces rather than the
    # sole defence — a new service-written controller is refused by default.
    it 'writes only what the Admin API documents a write body for' do
      undocumented = Spree::AgentTools::ResourceMap.all.select(&:generic_writes?).reject do |entry|
        Spree::Api::AgentWriteSchemas.attribute_names(entry.key).any?
      end

      expect(undocumented.map(&:key)).to be_empty
    end

    # The map keys resources by model name; the OpenAPI document keys them by
    # URL segment. Where the two disagree a resource silently loses its
    # writes, so a resource whose controller writes directly and documents a
    # body must resolve in both.
    it 'keys a writable resource the same way the OpenAPI document does' do
      # Everything deliberately read-only, for a reason recorded elsewhere:
      # written through a workflow, written through a Tier 1 service, gated
      # per request (imports and exports), or contested between two
      # controllers and therefore read-only by the collision rule.
      deliberate = Spree::AgentTools::ResourceMap.all.select do |entry|
        entry.create_workflow_key.present? || entry.update_workflow_key.present? ||
          Spree::Api::AgentResourceMap::SERVICE_WRITTEN_MODELS.include?(entry.model_name) ||
          Spree::Api::AgentResourceMap::DYNAMIC_SCOPE_RESOURCES.key?(entry.key) ||
          authority_keys.include?(entry.key) ||
          contested_keys.include?(entry.key)
      end

      # What is left should be writable exactly when the document says so, so
      # the map's model-derived key and the document's URL segment agree.
      mismatched = (Spree::AgentTools::ResourceMap.all - deliberate).reject do |entry|
        entry.generic_writes? == Spree::Api::AgentWriteSchemas.attribute_names(entry.key).any?
      end

      expect(mismatched.map(&:key)).to be_empty, <<~MESSAGE
        These resources are keyed one way in the map and another in
        docs/api-reference/admin.yaml, so their writes are silently lost:

          #{mismatched.map(&:key).join("\n  ")}
      MESSAGE
    end

    # Roles, role grants, invitations and API keys all run an
    # anti-amplification check: a caller may only hand out authority they hold
    # themselves. A generic write assigns attributes and saves, which knows
    # nothing about that — so those resources are never generically writable,
    # whatever the OpenAPI document happens to document.
    it 'never offers a generic write for a resource that hands out authority' do
      guarded = Spree::Api::AgentResourceMap.controllers.select do |controller|
        controller.include?(Spree::Api::V3::Admin::RoleGrantGuard)
      end

      expect(guarded).not_to be_empty, 'expected the anti-amplification guard to be in use somewhere'

      writable = guarded.filter_map do |controller|
        model = Spree::Api::AgentResourceMap.send(:safely, controller.allocate, :model_class)
        next if model.nil?

        entry = Spree::AgentTools::ResourceMap.all.find { |candidate| candidate.model_name == model.name }
        entry&.key if entry&.generic_writes?
      end

      expect(writable).to be_empty, <<~MESSAGE
        These resources decide who may do what, and their controllers guard
        against a caller granting authority they do not hold. A generic write
        would skip that guard:

          #{writable.join("\n  ")}
      MESSAGE
    end

    it 'scopes every registered resource to a store' do
      unscoped = Spree::AgentTools::ResourceMap.all.reject(&:store_scoped?)

      expect(unscoped.map(&:key)).to be_empty
    end
  end
end
