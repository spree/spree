require 'spec_helper'

RSpec.describe Spree::NamedType do
  # RefundReason is the one core model that seeds immutable records, so it is
  # the honest subject for the lock guard.
  describe 'immutable records' do
    let!(:locked) { Spree::RefundReason.return_processing_reason }

    it 'refuses a rename' do
      locked.name = 'Something else'

      expect(locked.save).to be(false)
      expect(locked.errors[:name]).to be_present
    end

    it 'refuses a destroy' do
      expect { locked.destroy }.not_to change(Spree::RefundReason, :count)
      expect(locked.errors[:base]).to be_present
    end

    it 'still allows deactivating it' do
      expect(locked.update(active: false)).to be(true)
    end

    it 'reports that it cannot be deleted' do
      expect(locked.can_be_deleted?).to be(false)
    end
  end

  describe 'ordinary records' do
    let!(:reason) { create(:return_reason, name: 'Wrong size') }

    it 'can be renamed' do
      expect(reason.update(name: 'Too small')).to be(true)
    end

    it 'can be deleted' do
      expect { reason.destroy }.to change(Spree::ReturnReason, :count).by(-1)
    end

    it 'reports that it can be deleted' do
      expect(reason.can_be_deleted?).to be(true)
    end
  end

  # StoreCreditCategory has no mutable column; the guard must not assume one.
  describe 'a NamedType without a mutable column' do
    it 'behaves normally' do
      category = create(:store_credit_category, name: 'Refund')

      expect(category.update(name: 'Goodwill')).to be(true)
      expect(category.can_be_deleted?).to be(true)
    end
  end
end
