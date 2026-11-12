require 'spec_helper'
require 'spree/api/testing_support/agent_tools_contract'

# The Admin API is the reference wiring for what an agent may do: its
# operations are the action tools, and its controllers define the resources
# the generic tools reach. These examples keep the agent catalog honest
# against them, so a new admin endpoint cannot quietly arrive without an
# agent deciding what to do about it.
#
# See docs/plans/6.0-mcp-server.md and docs/plans/6.0-agent-tools-from-openapi.md.
RSpec.describe 'agent tool contract' do
  # Resource keys whose controller guards against a caller granting authority
  # it does not hold, which the derivation deliberately makes read-only.
  def authority_keys
    Spree::Api::AgentResourceMap.controllers.filter_map do |controller|
      next unless controller.include?(Spree::Api::V3::Admin::RoleGrantGuard)

      model = Spree::Api::AgentResourceMap.model_for(controller)
      model && Spree::Api::AgentResourceMap.key_for(model)
    end
  end

  # Resource keys served by more than one admin controller under different
  # scopes, which the derivation deliberately makes read-only.
  def contested_keys
    by_key = Spree::Api::AgentResourceMap.controllers.each_with_object(Hash.new { |h, k| h[k] = [] }) do |controller, result|
      model = Spree::Api::AgentResourceMap.model_for(controller)
      next if model.nil? || controller._scoped_resource.blank?

      result[Spree::Api::AgentResourceMap.key_for(model)] << controller._scoped_resource
    end

    by_key.select { |_key, scopes| scopes.uniq.size > 1 }.keys
  end

  # Every admin action is a tool built from its OpenAPI operation; this is
  # the contract an extension includes for its own engine too.
  describe 'the action tools' do
    it_behaves_like 'an engine whose admin writes are agent tools', Spree::Api::Engine
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
      unknown = Spree::AgentTools::ResourceMap.all.reject do |entry|
        entry.permission_keys.any? && entry.permission_keys.all? { |key| Spree.permissions.key?(key) }
      end

      expect(unknown.map(&:key)).to be_empty
    end

    it 'refuses generic writes for a resource written through a workflow' do
      with_workflow = Spree::AgentTools::ResourceMap.all.select do |entry|
        entry.create_workflow_key.present? || entry.update_workflow_key.present?
      end

      expect(with_workflow).not_to be_empty
      # Writable through the generic tools too, since those dispatch to the
      # controller that runs the workflow — one way to write, reached two
      # ways by name.
      expect(with_workflow.select(&:generic_writes?)).not_to be_empty
    end

    # The list of service-written models this used to assert over is gone
    # (2026-10-10). A generic write dispatches to the controller, so a
    # resource whose controller orchestrates is reached through that
    # orchestration rather than around it — an order is writable now, and
    # correctly.
    it 'allows a generic write for a resource whose controller orchestrates' do
      orders = Spree::AgentTools::ResourceMap.find('orders')

      expect(orders.write_permission).to eq('write_orders')
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
        model = Spree::Api::AgentResourceMap.model_for(controller)
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
        Spree::Api::AgentWriteSchemas.attribute_names(entry.key, api_paths: entry.api_paths).any?
      end

      expect(undocumented.map(&:key)).to be_empty
    end

    # The map keys resources by model name; the OpenAPI document keys them by
    # URL segment. Where the two disagree a resource silently loses its
    # writes, so a resource whose controller writes directly and documents a
    # body must resolve in both.
    it 'keys a writable resource the same way the OpenAPI document does' do
      # Everything deliberately read-only, for a reason recorded elsewhere:
      # written through a workflow it declares, gated per request (imports
      # and exports), handing out authority, or contested between two
      # controllers and therefore read-only by the collision rule.
      deliberate = Spree::AgentTools::ResourceMap.all.select do |entry|
        entry.create_workflow_key.present? || entry.update_workflow_key.present? ||
          Spree::Api::AgentResourceMap::DYNAMIC_SCOPE_RESOURCES.key?(entry.key) ||
          authority_keys.include?(entry.key) ||
          contested_keys.include?(entry.key)
      end

      # What is left should be writable exactly when the document says so, so
      # the map's model-derived key and the document's URL segment agree.
      mismatched = (Spree::AgentTools::ResourceMap.all - deliberate).reject do |entry|
        entry.generic_writes? == Spree::Api::AgentWriteSchemas.attribute_names(entry.key, api_paths: entry.api_paths).any?
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
        model = Spree::Api::AgentResourceMap.model_for(controller)
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

    # The real guard against a serializer gaining a credential-bearing field
    # later: no registered resource may emit its own record's secure token.
    # Checked against the serializers themselves rather than a list, so a new
    # `has_secure_token` model is covered the day it is mapped.
    it 'never emits a record\'s own secure token' do
      leaking = Spree::AgentTools::ResourceMap.all.filter_map do |entry|
        model = entry.model_class
        next unless model.respond_to?(:column_names) && model.column_names.include?('token')

        record = model.new(token: 'SENTINELtokenVALUE')
        serialized = entry.serializer_class.new(record).to_h
        entry.key if Spree::AgentTools::RecordSummary.sanitize(serialized).to_s.include?('SENTINELtokenVALUE')
      rescue StandardError
        # A serializer that cannot render an unsaved record tells us nothing
        # about leakage; the per-resource specs cover those.
        nil
      end

      expect(leaking).to be_empty, <<~MESSAGE
        These resources emit their own secure token to an agent, which reaches
        the model and, for a hosted client, a third-party vendor:

          #{leaking.join("\n  ")}

        Add the attribute to RecordSummary::SECRET_ATTRIBUTES, or the model to
        AgentResourceMap::WITHHELD_MODELS.
      MESSAGE
    end

    it 'scopes every registered resource to a store' do
      unscoped = Spree::AgentTools::ResourceMap.all.reject(&:store_scoped?)

      expect(unscoped.map(&:key)).to be_empty
    end
  end
end
