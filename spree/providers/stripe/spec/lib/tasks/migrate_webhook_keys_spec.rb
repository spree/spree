require 'spec_helper'
require 'rake'

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
load SpreeStripe::Engine.root.join('lib', 'tasks', 'migrate_webhook_keys.rake')

describe SpreeStripe::WebhookKeysMigrator do

  let(:connection) { ActiveRecord::Base.connection }
  let(:gateway) { create(:stripe_gateway) }

  # The legacy tables are gone from 6.0 schemas, so the example builds them in
  # the shape a 5.x install left behind.
  before do
    connection.create_table(described_class::LEGACY_KEYS_TABLE, force: true) do |t|
      t.string :stripe_id
      t.string :signing_secret
      t.timestamps
    end
    connection.create_table(described_class::LEGACY_JOIN_TABLE, force: true) do |t|
      t.bigint :payment_method_id
      t.bigint :webhook_key_id
      t.timestamps
    end

    key = described_class.new.send(:key_model).create!(stripe_id: 'we_legacy', signing_secret: 'whsec_legacy')
    connection.insert(
      "INSERT INTO #{described_class::LEGACY_JOIN_TABLE} (payment_method_id, webhook_key_id, created_at, updated_at) " \
      "VALUES (#{gateway.id}, #{key.id}, #{connection.quote(Time.current)}, #{connection.quote(Time.current)})"
    )
  end

  after do
    connection.drop_table described_class::LEGACY_KEYS_TABLE, if_exists: true
    connection.drop_table described_class::LEGACY_JOIN_TABLE, if_exists: true
  end

  it 'moves the signing secret into the encrypted column, never into preferences' do
    expect(described_class.new.call).to include(migrated: 1)

    reloaded = SpreeStripe::Gateway.find(gateway.id)
    expect(reloaded.preferred_webhook_signing_secret).to eq('whsec_legacy')
    expect(reloaded.preferred_webhook_endpoint_id).to eq('we_legacy')
    expect(reloaded.preferences).not_to have_key('webhook_signing_secret')

    raw = connection.select_value("SELECT secret_preferences FROM spree_payment_methods WHERE id = #{gateway.id}")
    expect(raw).not_to include('whsec_legacy')
  end
end
