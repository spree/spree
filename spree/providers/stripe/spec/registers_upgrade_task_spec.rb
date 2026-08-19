require 'spec_helper'

RSpec.describe 'the Stripe upgrade step' do
  # The manifest marks this step optional because the class ships here rather
  # than in core; an installation with the gem must therefore find it.
  it 'is registered when this gem is loaded' do
    expect(Spree::MaintenanceTask.find_registered('SpreeStripe::MaintenanceTasks::MigrateWebhookKeys')).to be_present
  end

  it 'runs the rake task the manifest names' do
    expect(SpreeStripe::MaintenanceTasks::MigrateWebhookKeys.rake_task_name).
      to eq('spree:upgrade:migrate_stripe_webhook_keys')
  end
end
