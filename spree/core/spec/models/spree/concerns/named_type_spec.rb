require 'spec_helper'

RSpec.describe Spree::NamedType do
  describe 'name uniqueness' do
    let!(:existing) { create(:return_reason, name: 'Wrong size') }

    it 'rejects a duplicate name within the same store' do
      duplicate = build(:return_reason, store: existing.store, name: 'Wrong size')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it 'rejects a duplicate that differs only in case' do
      duplicate = build(:return_reason, store: existing.store, name: 'WRONG SIZE')

      expect(duplicate).not_to be_valid
    end

    it 'allows the same name in another store' do
      expect(build(:return_reason, store: create(:store), name: 'Wrong size')).to be_valid
    end
  end

  describe 'name normalization' do
    it 'squishes surrounding and repeated whitespace' do
      reason = create(:return_reason, name: '  Wrong   size  ')

      expect(reason.name).to eq('Wrong size')
    end
  end

  describe 'deleting a reason that is in use' do
    let(:reason) { create(:return_reason, name: 'Wrong size') }

    before { create(:return, reason: reason) }

    it 'refuses the destroy' do
      expect { reason.destroy }.not_to change(Spree::ReturnReason, :count)
      expect(reason.errors[:base]).to be_present
    end

    it 'reports that it cannot be deleted' do
      expect(reason.can_be_deleted?).to be(false)
    end
  end

  describe 'deleting an unused reason' do
    let!(:reason) { create(:return_reason, name: 'Wrong size') }

    it 'succeeds' do
      expect { reason.destroy }.to change(Spree::ReturnReason, :count).by(-1)
    end

    it 'reports that it can be deleted' do
      expect(reason.can_be_deleted?).to be(true)
    end

    it 'can be renamed' do
      expect(reason.update(name: 'Too small')).to be(true)
    end
  end
end
