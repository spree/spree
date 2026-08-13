require 'spec_helper'

# Three things guard number uniqueness, and each catches what the one before
# it cannot: the generator's pre-check (cheap, advisory), the uniqueness
# validation from Spree::NumberIdentifier, and the database's unique index —
# the only one that holds when two writers commit at the same instant.
RSpec.describe 'Spree::HasNumber uniqueness guards' do
  # Created before any stubbing so it numbers itself normally.
  let!(:taken) { create(:order).number }

  def generating(*candidates)
    generator = instance_double(Spree::NumberGenerators::Sequential)
    allow(Spree::NumberGenerators::Sequential).to receive(:new).and_return(generator)
    allow(generator).to receive(:generate).and_return(*candidates)

    yield
  end

  it 'skips a taken candidate before it reaches the database' do
    order = build(:order)

    generating(taken, 'R-SECOND-TRY') { order.save! }

    expect(order.reload.number).to eq('R-SECOND-TRY')
  end

  it 'recovers from a duplicate that slips past the pre-check' do
    order = build(:order)
    # Simulates another writer committing between the pre-check and the insert.
    allow_any_instance_of(Spree::Order).to receive(:number_taken?).and_return(false)

    generating(taken, 'R-AFTER-RACE') do
      expect { order.save! }.to raise_error(ActiveRecord::RecordInvalid, /Number has already been taken/)
    end
  end

  # With validation skipped the index is the only guard left, so this is the
  # path a true concurrent commit takes.
  it 'renumbers and saves when the index rejects the insert' do
    order = build(:order)
    allow_any_instance_of(Spree::Order).to receive(:number_taken?).and_return(false)

    generating(taken, 'R-INDEX-RETRY') do
      order.generate_number
      order.save!(validate: false)
    end

    expect(order.reload.number).to eq('R-INDEX-RETRY')
  end

  it 'gives up when the renumber collides too' do
    order = build(:order)
    allow_any_instance_of(Spree::Order).to receive(:number_taken?).and_return(false)

    generating(taken) do
      order.generate_number
      expect { order.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
