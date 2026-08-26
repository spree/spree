require 'spec_helper'

# Owners name their default slots differently — a customer keeps
# bill_address_id, a company node default_bill_address_id — so the flags are
# exercised against both to prove the concern, not one owner's columns.
RSpec.describe Spree::HasAddressBook do
  let(:store) { @default_store }

  shared_examples 'an address book owner' do
    it 'promotes the address to both slots' do
      owner.assign_default_address(address_id: address.id)

      expect(owner.default_address_id(:bill)).to eq(address.id)
      expect(owner.default_address_id(:ship)).to eq(address.id)
    end

    it 'promotes only the slot asked for' do
      owner.assign_default_address(address_id: address.id, billing: true, shipping: false)

      expect(owner.default_address_id(:bill)).to eq(address.id)
      expect(owner.default_address_id(:ship)).to be_nil
    end

    it 'gives up a slot this address holds' do
      owner.assign_default_address(address_id: address.id)
      owner.assign_default_address(address_id: address.id, billing: false, shipping: false)

      expect(owner.default_address_id(:bill)).to be_nil
      expect(owner.default_address_id(:ship)).to be_nil
    end

    # Another entry's default is not this caller's business.
    it 'leaves a slot another address holds' do
      owner.assign_default_address(address_id: other_address.id)
      owner.assign_default_address(address_id: address.id, billing: false, shipping: false)

      expect(owner.default_address_id(:bill)).to eq(other_address.id)
    end

    # The release is a conditional update, not a read-then-write: a promotion
    # that lands between the two must survive. Simulated by moving the slot
    # behind this instance's back, which is exactly what the other request
    # would have done.
    it 'does not undo a promotion that landed after it read the slot' do
      owner.assign_default_address(address_id: address.id)
      owner.default_address_id(:bill) # the stale read this request would hold

      owner.class.where(id: owner.id).
        update_all(owner.default_address_columns[:bill] => other_address.id)

      owner.assign_default_address(address_id: address.id, billing: false, shipping: nil)

      expect(owner.reload.default_address_id(:bill)).to eq(other_address.id)
    end

    it 'leaves a slot alone when the flag is nil' do
      owner.assign_default_address(address_id: other_address.id)
      owner.assign_default_address(address_id: address.id, billing: nil, shipping: nil)

      expect(owner.default_address_id(:bill)).to eq(other_address.id)
    end
  end

  context 'a customer' do
    let(:owner) { create(:user) }
    let(:address) { create(:address, owner: owner) }
    let(:other_address) { create(:address, owner: owner) }

    it_behaves_like 'an address book owner'
  end

  context 'a company node' do
    let(:owner) { create(:company, store: store) }
    let(:address) { create(:company_address, owner: owner) }
    let(:other_address) { create(:company_address, owner: owner) }

    it_behaves_like 'an address book owner'
  end
end
