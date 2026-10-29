require 'spec_helper'
require 'spree/upgrade'

RSpec.describe 'the PayPal upgrade steps' do
  # The manifest marks both steps optional because they ship here rather than
  # in core; an installation with the gem must therefore find them.
  it 'registers the payment migration' do
    expect(Spree::MaintenanceTask.find_registered('SpreePaypalCheckout::MaintenanceTasks::MigratePayments')).to be_present
  end

  # A web or worker process never loads the Rakefile, so a run started from
  # the dashboard has to find the task in this gem.
  it 'finds the webhook task in this gem outside the command line' do
    path = Spree::MaintenanceTask.new.rake_file_defining('spree:upgrade:register_paypal_webhooks')

    expect(path).to start_with(SpreePaypalCheckout::Engine.root.to_s)
  end

  it 'offers both steps where the gem is installed' do
    %w[migrate_paypal_payments register_paypal_webhooks].each do |id|
      step = Spree::Upgrade.find_step(id)

      expect(step).to be_present
      expect(step['optional']).to be(true)
      expect(Spree::Upgrade.available?(step)).to be(true), "#{id} should be available"
    end
  end

  it 'runs both after the Stripe webhook key step' do
    ids = Spree::Upgrade.manifests.find { |manifest| manifest['to'] == '6.0' }['steps'].map { |step| step['id'] }

    expect(ids.index('migrate_paypal_payments')).to eq(ids.index('migrate_stripe_webhook_keys') + 1)
    expect(ids.index('register_paypal_webhooks')).to eq(ids.index('migrate_paypal_payments') + 1)
  end
end
