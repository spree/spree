require 'spec_helper'

RSpec.shared_examples 'a purchase validations host' do
  describe 'money columns' do
    it 'rejects a negative positive-only total' do
      record = new_record(item_total: -1)

      expect(record).not_to be_valid
      expect(record.errors[:item_total]).to be_present
    end

    it 'rejects a positive discount_total' do
      record = new_record(discount_total: 3)

      expect(record).not_to be_valid
      expect(record.errors[:discount_total]).to be_present
    end

    it 'rejects totals beyond the money threshold' do
      record = new_record(total: Spree::Purchase::Validations::MONEY_THRESHOLD)

      expect(record).not_to be_valid
      expect(record.errors[:total]).to be_present
    end
  end

  describe 'total_quantity' do
    it 'rejects negative and fractional quantities' do
      expect(new_record(total_quantity: -1)).not_to be_valid
      expect(new_record(total_quantity: 1.5)).not_to be_valid
      expect(new_record(total_quantity: 3)).to be_valid
    end
  end

end

RSpec.describe Spree::Purchase::Validations do
  let(:store) { @default_store }

  context 'included in Spree::Cart' do
    def new_record(**attributes)
      build(:cart, store: @default_store, **attributes)
    end

    it_behaves_like 'a purchase validations host'
  end

  context 'included in Spree::Order' do
    def new_record(**attributes)
      build(:order, store: @default_store, email: 'buyer@example.com', **attributes)
    end

    it_behaves_like 'a purchase validations host'
  end
end
