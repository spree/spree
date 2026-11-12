require 'spree/api/testing_support/agent_tools'

# The contract between an engine's admin endpoints and the agent tools built
# from them. Core includes it, and so does every extension that adds admin
# endpoints:
#
#   require 'spree/api/testing_support/agent_tools_contract'
#
#   RSpec.describe 'agent tools' do
#     it_behaves_like 'an engine whose admin writes are agent tools', MyExtension::Engine
#   end
#
# An admin write cannot land without an operation describing it, an opt-out
# without its reason, or two operations claiming one tool name.
#
# See docs/plans/6.0-agent-tools-from-openapi.md.
RSpec.shared_examples 'an engine whose admin writes are agent tools' do |engine|
  operations = Spree::Api::AgentOperations
  root = engine.root.to_s
  defined_here = lambda do |controller|
    controller && Object.const_source_location(controller.name)&.first&.start_with?(root)
  end

  # The admin operations this engine's own controllers serve.
  let(:engine_candidates) do
    operations.candidates.select { |candidate| defined_here.call(candidate.dig(:route, :controller)) }
  end

  let(:engine_routes) do
    operations.admin_routes.filter_map do |route|
      next unless operations::WRITE_VERBS.include?(route[:verb]) && !operations::CRUD_ACTIONS.include?(route[:action])

      [route[:verb], route[:path]] if defined_here.call(route[:controller])
    end.uniq
  end

  # The tool name each listed action derives, before collisions are settled.
  let(:included_names) do
    engine_candidates.select { |candidate| operations.disposition(candidate) == :included }.
      map { |candidate| operations.tool_name(candidate) }
  end

  it 'documents every admin action its controllers serve' do
    paths = Spree::Api::AdminDocument.document['paths'] || {}
    undocumented = engine_routes.reject { |verb, path| paths.dig(path, verb) }.
                   map { |verb, path| "#{verb.upcase} #{path}" }

    expect(undocumented).to be_empty, <<~MESSAGE
      These admin actions have no operation in the engine's OpenAPI document, so no
      agent tool and no API reference describes them:

        #{undocumented.join("\n  ")}

      Write an rswag integration spec for each, then regenerate the document.
    MESSAGE
  end

  it 'gives every opt-out a reason' do
    unexplained = engine_candidates.filter_map do |candidate|
      operation = candidate[:operation]
      next unless operation[operations::AGENT_KEY] == false && operation[operations::REASON_KEY].blank?

      "#{candidate[:verb].upcase} #{candidate[:path]}"
    end

    expect(unexplained).to be_empty
  end

  # Across every engine, not only this one: an extension's action deriving
  # a core name would otherwise lose to the shallower path, quietly.
  it 'derives a distinct tool name for every action' do
    every_name = operations.candidates.select { |candidate| operations.disposition(candidate) == :included }.
                 map { |candidate| operations.tool_name(candidate) }
    duplicated = every_name.tally.select { |name, count| count > 1 && included_names.include?(name) }.keys

    expect(duplicated).to be_empty, "Give these operations an operationId: #{duplicated.join(', ')}"
  end

  # A hand-registered tool keeps its name, so an operation deriving the same
  # one would vanish from every agent surface.
  it 'claims no name a hand-written tool already has' do
    hand_written = Spree.admin_agent_tools.send(:registered_classes).map(&:tool_name)

    expect(included_names & hand_written).to be_empty
  end

  it 'merges its document into core\'s without a conflict' do
    expect(Spree::Api::AdminDocument.conflicts).to be_empty
  end

  it 'names every tool the way MCP accepts' do
    catalog = Spree::AgentTools::OperationCatalog
    invalid = (catalog.all + catalog.aliases).map(&:name).
              reject { |name| name.match?(/\A[a-zA-Z0-9_-]{1,64}\z/) }

    expect(invalid).to be_empty
  end

  it 'gives every tool a summary and a permission the catalog knows' do
    faults = included_names.filter_map do |name|
      entry = Spree::AgentTools::OperationCatalog.find(name)
      next "#{name}: not registered" if entry.nil?
      next "#{name}: no summary" if entry.summary.blank?

      "#{name}: unknown permission #{entry.permission}" unless Spree.permissions.key?(entry.permission)
    end

    expect(faults).to be_empty
  end
end
