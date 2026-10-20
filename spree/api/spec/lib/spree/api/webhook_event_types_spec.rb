require 'spec_helper'
require Spree::Api::Engine.root.join('lib/spree/api/webhook_event_types').to_s

RSpec.describe Spree::Api::WebhookEventTypes do
  subject(:generator) { described_class.new }

  let(:monorepo_root) { Spree::Api::Engine.root.join('../..') }

  before { Rails.autoloaders.main.eager_load_dir(Spree::Api::Engine.root.join('app/serializers/spree/api/v3').to_s) }

  it 'matches the committed SDK files (run `bundle exec rake typelizer:generate` to refresh them)' do
    generator.render.each do |key, source|
      path = monorepo_root.join(described_class::FILES.fetch(key))

      expect(path.read).to eq(source), "#{path.relative_path_from(monorepo_root)} is out of date with the event catalog"
    end
  end

  it 'has a dashboard label for every event group, in every language' do
    groups = Spree::Events.catalog.webhook_events.map(&:group).uniq

    Dir[monorepo_root.join('packages/dashboard/src/locales/*.json')].each do |file|
      labels = JSON.parse(File.read(file)).dig('admin', 'pages', 'settings', 'webhooks', 'event_groups')

      expect(groups - labels.keys).to be_empty, "#{File.basename(file)} has no label for #{(groups - labels.keys).join(', ')}"
    end
  end

  it 'types a deprecated alias with the event that replaces it' do
    expect(generator.render[:types]).to include(
      "  /** @deprecated Use `order.placed` instead. */\n  'order.completed': Order"
    )
  end

  it 'refuses an event built by a back-office serializer, or a Store-level class inheriting one' do
    catalog = Spree::Events::Catalog.new
    catalog.instance_variable_set(:@loaded, true)
    stub_const('Spree::Api::V3::OrderAuditEventSerializer', Class.new(Spree::Api::V3::Admin::OrderSerializer))
    catalog.declare(Spree::Order, :audited, serializer: 'Spree::Api::V3::OrderAuditEventSerializer')

    expect { described_class.new(catalog).render }.to raise_error(ArgumentError, /not a Store API serializer/)
  end
end
