require 'spec_helper'
require 'spree/upgrade'

RSpec.describe 'the Adyen upgrade steps' do
  # The manifest marks both steps optional because they ship here rather than
  # in core; an installation with the gem must therefore find them.
  it 'registers the payment migration' do
    expect(Spree::MaintenanceTask.find_registered('SpreeAdyen::MaintenanceTasks::MigratePayments')).to be_present
  end

  # A web or worker process never loads the Rakefile, so a run started from
  # the dashboard has to find the task in this gem.
  it 'finds the configuration task in this gem outside the command line' do
    path = Spree::MaintenanceTask.new.rake_file_defining('spree:upgrade:configure_adyen_gateways')

    expect(path).to start_with(SpreeAdyen::Engine.root.to_s)
  end

  it 'offers both steps where the gem is installed' do
    %w[migrate_adyen_payments configure_adyen_gateways].each do |id|
      step = Spree::Upgrade.find_step(id)

      expect(step).to be_present
      expect(step['optional']).to be(true)
      expect(Spree::Upgrade.available?(step)).to be(true), "#{id} should be available"
    end
  end

  it "runs both after core's settlement status backfill" do
    ids = Spree::Upgrade.manifests.find { |manifest| manifest['to'] == '6.0' }['steps'].pluck('id')

    expect(ids.index('migrate_adyen_payments')).to eq(ids.index('backfill_settlement_statuses') + 1)
    expect(ids.index('configure_adyen_gateways')).to eq(ids.index('migrate_adyen_payments') + 1)
  end
end
