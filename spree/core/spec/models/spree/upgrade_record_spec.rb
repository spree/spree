require 'spec_helper'

RSpec.describe Spree::UpgradeRecord do
  it 'records a completed boundary' do
    record = described_class.stamp!('5.6', source: 'walk')

    expect(record.version).to eq('5.6')
    expect(record.completed_at).to be_present
  end

  # A walk that runs twice must not fail on the second pass.
  it 'is idempotent for the same boundary' do
    described_class.stamp!('5.6', source: 'walk')

    expect { described_class.stamp!('5.6', source: 'walk') }.not_to change(described_class, :count)
  end

  it 'refuses a source it does not recognise' do
    record = described_class.new(version: '5.6', source: 'guessing', completed_at: Time.current)

    expect(record).not_to be_valid
  end

  describe '.current_version' do
    it 'is nil before anything is recorded' do
      expect(described_class.current_version).to be_nil
    end

    # Compared as versions, not strings: "5.10" is above "5.9".
    it 'is the highest boundary recorded' do
      described_class.stamp!('5.6', source: 'walk')
      described_class.stamp!('5.10', source: 'walk')
      described_class.stamp!('5.9', source: 'walk')

      expect(described_class.current_version).to eq('5.10')
    end
  end
end

RSpec.describe Spree::Upgrade do
  describe '.pending_steps' do
    # The list would otherwise grow with every release Spree ships, and a store
    # that upgraded last release would be offered steps it must never re-run.
    it 'starts from the boundary already completed' do
      Spree::UpgradeRecord.stamp!('5.6', source: 'walk')

      boundaries = described_class.pending_steps.map { |step| step['from'] }.uniq

      expect(boundaries).to eq(['5.6'])
    end

    it 'offers every manifest to a store far enough behind' do
      Spree::UpgradeRecord.stamp!('5.4', source: 'manual')

      boundaries = described_class.pending_steps.map { |step| step['from'] }.uniq

      expect(boundaries.size).to be > 1
    end

    # A database created by today's schema has no historical data to convert.
    it 'has nothing left for a freshly seeded installation' do
      described_class.manifests.each { |m| Spree::UpgradeRecord.stamp!(m['to'], source: 'install') }

      expect(described_class.pending_steps).to be_empty
    end

    it 'never offers steps of a release beyond the installed one' do
      versions = described_class.pending_steps.map { |step| step['to'] }.uniq

      expect(versions).to all(satisfy { |v| described_class.compare(v, described_class.installed_minor_version) <= 0 })
    end
  end

  describe 'the assumed boundary' do
    # Without a stamp the starting point is a guess. Showing the single most
    # likely boundary beats showing every step ever written, but the guess has
    # to be reported as one so a long-postponed upgrade can find the rest.
    it 'falls back to the release below the installed one' do
      expect(described_class.completed_boundary).to eq('5.6')
      expect(described_class.completed_boundary_known?).to be(false)
    end

    it 'is known once something records it' do
      Spree::UpgradeRecord.stamp!('5.6', source: 'walk')

      expect(described_class.completed_boundary_known?).to be(true)
    end

    it 'counts the steps it is leaving out' do
      expect(described_class.superseded_steps).not_to be_empty
    end
  end
end
