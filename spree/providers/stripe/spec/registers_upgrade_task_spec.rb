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

  # A web or worker process never loads the Rakefile, so a run started from
  # the dashboard has to find the task in this gem, not only in core.
  it 'finds the rake task outside the command line' do
    path = SpreeStripe::MaintenanceTasks::MigrateWebhookKeys.new.rake_file_defining('spree:upgrade:migrate_stripe_webhook_keys')

    expect(path).to start_with(SpreeStripe::Engine.root.to_s)
  end
end
