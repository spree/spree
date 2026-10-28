require 'spec_helper'

RSpec.describe Spree::MaintenanceTasks::Upgrade::StoreTimeZones do
  let(:store) { create(:store) }

  def store_time_zone(value)
    store.update_columns(preferences: store.preferences.merge(timezone: value))
  end

  def run_task
    result = Spree::MaintenanceTasks::Start.call(task_name: described_class.name, initiated_via: 'cli')
    Spree::MaintenanceTasks::RunJob.perform_now(result.value.id)
    result.value.reload
  end

  it 'converts a Rails time zone name to its IANA name' do
    store_time_zone('Eastern Time (US & Canada)')

    run = run_task

    expect(store.reload.preferred_timezone).to eq('America/New_York')
    expect(run.tallies['converted']).to eq(1)
  end

  it 'counts a value that names no time zone and leaves it alone' do
    store_time_zone('Mars/Olympus_Mons')

    run = run_task

    expect(store.reload.preferred_timezone).to eq('Mars/Olympus_Mons')
    expect(run.tallies['unknown']).to eq(1)
  end

  it 'leaves a store already on an IANA name unchanged' do
    store_time_zone('Europe/Berlin')

    run_task

    expect(store.reload.preferred_timezone).to eq('Europe/Berlin')
  end
end
