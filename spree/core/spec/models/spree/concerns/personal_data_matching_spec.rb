require 'spec_helper'

describe Spree::PersonalDataMatching do
  subject(:matcher) { Class.new { include Spree::PersonalDataMatching }.new }

  describe '#with_email' do
    let!(:order) { create(:order).tap { |order| order.update_columns(email: 'Ada@Example.com') } }

    it 'matches the address whatever its casing' do
      expect(matcher.send(:with_email, Spree::Order, 'ada@example.com')).to eq([order])
    end

    # An app may encrypt the column, deterministically so it can still be
    # looked up. SQL then only ever sees ciphertext.
    context 'when the app encrypts email' do
      let(:order_class) do
        stub_const('EncryptedEmailOrder', Class.new(Spree::Order) do
          self.table_name = Spree::Order.table_name
          encrypts :email, deterministic: true, downcase: true
        end)
      end

      before { order_class.find(order.id).update_columns(email: 'Ada@Example.com') }

      it 'matches the address whatever its casing' do
        stored = order_class.connection.select_value(order_class.unscoped.where(id: order.id).select(:email).to_sql)
        expect(stored).not_to include('example.com')

        expect(matcher.send(:with_email, order_class, 'ADA@example.com').ids).to eq([order.id])
      end
    end
  end
end
