require 'spec_helper'

RSpec.describe Spree::MaintenanceTasks::Upgrade::StoreRegionalSettings do
  let(:store) { create(:store, code: "regional-#{SecureRandom.hex(4)}") }

  def store_settings(**settings)
    store.update_columns(preferences: store.preferences.merge(settings))
  end

  def run_task
    result = Spree::MaintenanceTasks::Start.call(task_name: described_class.name, initiated_via: 'cli')
    Spree::MaintenanceTasks::RunJob.perform_now(result.value.id)
    result.value.reload
  end

  it 'converts a Rails time zone name to its IANA name' do
    store_settings(timezone: 'Eastern Time (US & Canada)')

    run = run_task

    expect(store.reload.preferred_timezone).to eq('America/New_York')
    expect(run.tallies['time_zone_converted']).to eq(1)
  end

  it 'resets a value that names no time zone to the default' do
    store_settings(timezone: 'Mars/Olympus_Mons')

    run = run_task

    expect(store.reload.preferred_timezone).to eq(store.preference_default(:timezone))
    expect(run.tallies['time_zone_reset_to_default']).to eq(1)
  end

  it 'converts an admin language to its listed code and clears one Spree does not list' do
    other_store = create(:store, code: "regional-#{SecureRandom.hex(4)}")
    store_settings(admin_locale: 'en_US')
    other_store.update_columns(preferences: other_store.preferences.merge(admin_locale: 'klingon'))

    run = run_task

    expect(store.reload.preferred_admin_locale).to eq('en-US')
    expect(other_store.reload.preferred_admin_locale).to be_blank
    expect(run.tallies).to include('admin_locale_converted' => 1, 'admin_locale_cleared' => 1)
  end

  it 'leaves a store already on an IANA name and a listed language unchanged' do
    store_settings(timezone: 'Europe/Berlin', admin_locale: 'de')

    run_task

    expect(store.reload).to have_attributes(preferred_timezone: 'Europe/Berlin', preferred_admin_locale: 'de')
  end
end
