require 'spec_helper'

RSpec.describe Spree::Seeds::States do
  before { Spree::Seeds::Countries.call }

  subject(:seed) { described_class.call }

  # Regression: countries were matched against Carmen by name, but Spree stores
  # the official ISO-3166 name ("United States of America") where Carmen uses
  # the common one ("United States"). The lookup missed, the `next unless`
  # skipped it silently, and the US ended up with zero states — which in turn
  # made every US address invalid ("State can't be blank").
  it 'seeds states for the US' do
    seed

    us = Spree::Country.find_by(iso: 'US')
    expect(us.states.count).to be > 50
    expect(us.states.find_by(abbr: 'IL')&.name).to eq('Illinois')
  end

  it 'seeds states for the other countries that require them' do
    seed

    %w[CA AU].each do |iso|
      expect(Spree::Country.find_by(iso: iso).states).to be_any, "expected states for #{iso}"
    end
  end

  # Seeds re-run on every deploy. The province-level branch used a bare
  # `insert_all`, so each run duplicated those countries' states.
  it 'is idempotent' do
    seed

    expect { described_class.call }.not_to change(Spree::State, :count)
    expect(Spree::State.group(:country_id, :abbr).having('COUNT(*) > 1').count).to be_empty
  end

  it 'refreshes a renamed state in place' do
    seed

    illinois = Spree::Country.find_by(iso: 'US').states.find_by(abbr: 'IL')
    illinois.update!(name: 'Stale Name')

    expect { described_class.call }.not_to change(Spree::State, :count)
    expect(illinois.reload.name).to eq('Illinois')
  end
end
