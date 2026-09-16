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
        Spree::AgentTools::WorkflowSchema.new(Spree.public_send(key), except: Array(options[:except])).to_json_schema
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

    it 'never offers a principal parameter to the caller' do
      offered = catalog::WORKFLOWS.flat_map do |key, options|
        options = { permission: options } unless options.is_a?(Hash)
        schema = Spree::AgentTools::WorkflowSchema.new(Spree.public_send(key), except: Array(options[:except]))

        schema.parameters.filter_map do |parameter|
          "#{key}.#{parameter[:name]}" if Spree::AgentTools::WorkflowSchema::PRINCIPAL_PARAMETERS.include?(parameter[:name])
        end
      end

      expect(offered).to be_empty
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

    it 'scopes every registered resource to a store' do
      unscoped = Spree::AgentTools::ResourceMap.all.reject(&:store_scoped?)

      expect(unscoped.map(&:key)).to be_empty
    end
  end
end
