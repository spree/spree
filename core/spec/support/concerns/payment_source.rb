RSpec.shared_examples "a payment source" do
  let(:payment_source) { described_class.new }

  describe '#name' do
    it 'has to be implemented' do
      expect do
        payment_source.name
      end.not_to raise_error
    end
  end

  context "#can_capture?" do
    it "should be true if payment is pending" do
      payment = mock_model(Spree::Payment, pending?: true, created_at: Time.current)
      expect(payment_source.can_capture?(payment)).to be true
    end

    it "should be true if payment is checkout" do
      payment = mock_model(Spree::Payment, pending?: false, checkout?: true, created_at: Time.current)
      expect(payment_source.can_capture?(payment)).to be true
    end
  end

  context "#can_void?" do
    it "should be true if payment is not void" do
      payment = mock_model(Spree::Payment, failed?: false, void?: false)
      expect(payment_source.can_void?(payment)).to be true
    end
  end

  context "#can_credit?" do
    it "should be false if payment is not completed" do
      payment = mock_model(Spree::Payment, completed?: false)
      expect(payment_source.can_credit?(payment)).to be false
    end

    it "should be false when credit_allowed is zero" do
      payment = mock_model(Spree::Payment, completed?: true, credit_allowed: 0, order: mock_model(Spree::Order, payment_state: 'credit_owed'))
      expect(payment_source.can_credit?(payment)).to be false
    end
  end

  context "#associations" do
    it "should be able to access its payments" do
      expect { credit_card.payments.to_a }.not_to raise_error
    end
  end
end
