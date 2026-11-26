require 'spec_helper'

describe Spree::Purchase::Warnings do
  shared_examples 'warnings carried across a lock' do
    it 'locks with unsaved warnings and keeps them' do
      record.warnings = [{ code: 'delivery_unavailable' }]

      expect { record.with_lock {} }.not_to raise_error
      expect(record.warnings).to eq([{ code: 'delivery_unavailable' }])
    end

    it 'still refuses a lock over other unsaved changes' do
      record.email = 'changed@example.com'

      expect { record.lock! }.to raise_error(RuntimeError, /unpersisted changes/)
    end

    it 'does not count the warnings as a change inside the lock' do
      record.warnings = [{ code: 'delivery_unavailable' }]

      record.with_lock { expect(record).not_to be_changed }
    end

    it 'leaves a destroyed record to Rails' do
      record.destroy!

      expect { record.with_lock {} }.not_to raise_error
    end
  end

  context 'on a cart' do
    let(:record) { create(:cart) }

    include_examples 'warnings carried across a lock'
  end

  context 'on an order' do
    let(:record) { create(:order) }

    include_examples 'warnings carried across a lock'
  end
end
