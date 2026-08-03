require 'spec_helper'

RSpec.describe Spree::HasStatus do
  # Spree::Return is the reference consumer; testing through it keeps the
  # spec honest about how the concern behaves on a real model.
  let(:model) { Spree::Return }

  around do |example|
    original = model.statuses
    example.run
    model.statuses = original
  end

  it 'declares the valid values and a default' do
    expect(model.statuses).to eq(%w[requested approved received refunded canceled])
    expect(model.default_status).to eq('requested')
  end

  it 'generates a predicate per value' do
    record = model.new(status: 'received')

    expect(record).to be_received
    expect(record).not_to be_requested
  end

  it 'generates a scope per value' do
    expect(model.received.to_sql).to include("'received'")
  end

  it 'rejects a status outside the list' do
    record = model.new(status: 'teleported')

    expect(record).not_to be_valid
    expect(record.errors[:status]).to be_present
  end

  describe '.add_status' do
    it 'appends at the end by default' do
      model.add_status(:disputed)

      expect(model.statuses.last).to eq('disputed')
      expect(model.new(status: 'disputed')).to be_disputed
    end

    it 'inserts after a named status' do
      model.add_status(:inspecting, after: :received)

      expect(model.statuses).to eq(%w[requested approved received inspecting refunded canceled])
    end

    it 'accepts a record carrying the added status' do
      model.add_status(:inspecting, after: :received)
      record = model.new(status: 'inspecting')
      record.validate

      expect(record.errors[:status]).to be_empty
    end

    it 'is idempotent' do
      model.add_status(:inspecting)
      model.add_status(:inspecting)

      expect(model.statuses.count('inspecting')).to eq(1)
    end
  end
end
