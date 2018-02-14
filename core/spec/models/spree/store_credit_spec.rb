require 'spec_helper'

describe 'StoreCredit' do
  let(:currency) { 'TEST' }
  let(:store_credit) { build(:store_credit, store_credit_attrs) }
  let(:store_credit_attrs) { {} }

  describe 'callbacks' do
    subject { store_credit.save }

    context 'amount used is greater than zero' do
      subject { store_credit.destroy }

      let(:store_credit) { create(:store_credit, amount: 100, amount_used: 1) }
      let(:validation_message) { I18n.t('activerecord.errors.models.spree/store_credit.attributes.amount_used.greater_than_zero_restrict_delete') }

      it 'can not delete the store credit' do
        subject
        expect(store_credit.reload).to eq store_credit
        expect(store_credit.errors[:amount_used]).to include(validation_message)
      end
    end

    context 'category is a non-expiring type' do
      let!(:secondary_credit_type) { create(:secondary_credit_type) }
      let(:store_credit) { build(:store_credit, credit_type: nil) }

      before { allow(store_credit.category).to receive(:non_expiring?).and_return(true) }

      it 'sets the credit type to non-expiring' do
        subject
        expect(store_credit.credit_type.name).to eq secondary_credit_type.name
      end
    end

    context 'category is an expiring type' do
      before { allow(store_credit.category).to receive(:non_expiring?).and_return(false) }

      it 'sets the credit type to non-expiring' do
        subject
        expect(store_credit.credit_type.name).to eq 'Expiring'
      end
    end

    context 'the type is set' do
      let!(:secondary_credit_type) { create(:secondary_credit_type) }
      let(:store_credit) { build(:store_credit, credit_type: secondary_credit_type) }

      before { allow(store_credit.category).to receive(:non_expiring?).and_return(false) }

      it "doesn't overwrite the type" do
        expect { subject }.not_to change(store_credit, :credit_type)
      end
    end
  end

  describe 'validations' do
    describe 'used amount should not be greater than the credited amount' do
      context 'the used amount is defined' do
        let(:invalid_store_credit) { build(:store_credit, amount: 100, amount_used: 150) }

        it 'is not valid' do
          expect(invalid_store_credit).not_to be_valid
        end

        it 'sets the correct error message' do
          invalid_store_credit.valid?
          attribute_name = I18n.t('activerecord.attributes.spree/store_credit.amount_used')
          validation_message = I18n.t('activerecord.errors.models.spree/store_credit.attributes.amount_used.cannot_be_greater_than_amount')
          expected_error_message = "#{attribute_name} #{validation_message}"
          expect(invalid_store_credit.errors.full_messages).to include(expected_error_message)
        end
      end

      context 'the used amount is not defined yet' do
        let(:store_credit) { build(:store_credit, amount: 100) }

        it 'is valid' do
          expect(store_credit).to be_valid
        end
      end
    end

    describe 'amount used less than or equal to amount' do
      subject { build(:store_credit, amount_used: 101.0, amount: 100.0) }

      it 'is not valid' do
        expect(subject).not_to be_valid
      end

      it 'adds an error message about the invalid amount used' do
        subject.valid?
        text = I18n.t('activerecord.errors.models.spree/store_credit.attributes.amount_used.cannot_be_greater_than_amount')
        expect(subject.errors[:amount_used]).to include(text)
      end
    end

    describe 'amount authorized less than or equal to amount' do
      subject { build(:store_credit, amount_authorized: 101.0, amount: 100.0) }

      it 'is not valid' do
        expect(subject).not_to be_valid
      end

      it 'adds an error message about the invalid authorized amount' do
        subject.valid?
        text = I18n.t('activerecord.errors.models.spree/store_credit.attributes.amount_authorized.exceeds_total_credits')
        expect(subject.errors[:amount_authorized]).to include(text)
      end
    end
  end

  describe '#display_amount' do
    it 'returns a Spree::Money instance' do
      expect(store_credit.display_amount).to be_instance_of(Spree::Money)
    end
  end

  describe '#display_amount_used' do
    it 'returns a Spree::Money instance' do
      expect(store_credit.display_amount_used).to be_instance_of(Spree::Money)
    end
  end

  describe '#amount_remaining' do
    context 'the amount_used is not defined' do
      context 'the authorized amount is not defined' do
        it 'returns the credited amount' do
          expect(store_credit.amount_remaining).to eq store_credit.amount
        end
      end

      context 'the authorized amount is defined' do
        let(:authorized_amount) { 15.00 }

        before { store_credit.update_attributes(amount_authorized: authorized_amount) }

        it 'subtracts the authorized amount from the credited amount' do
          expect(store_credit.amount_remaining).to eq (store_credit.amount - authorized_amount)
        end
      end
    end

    context 'the amount_used is defined' do
      let(:amount_used) { 10.0 }

      before { store_credit.update_attributes(amount_used: amount_used) }

      context 'the authorized amount is not defined' do
        it 'subtracts the amount used from the credited amount' do
          expect(store_credit.amount_remaining).to eq (store_credit.amount - amount_used)
        end
      end

      context 'the authorized amount is defined' do
        let(:authorized_amount) { 15.00 }

        before { store_credit.update_attributes(amount_authorized: authorized_amount) }

        it 'subtracts the amount used and the authorized amount from the credited amount' do
          expect(store_credit.amount_remaining).to eq (store_credit.amount - amount_used - authorized_amount)
        end
      end
    end
  end

  describe '#authorize' do
    context 'amount is valid' do
      let(:authorization_amount)       { 1.0 }
      let(:added_authorization_amount) { 3.0 }
      let(:originator) { nil }

      context 'amount has not been authorized yet' do
        before { store_credit.update_attributes(amount_authorized: authorization_amount) }

        it 'returns true' do
          expect(store_credit.authorize(store_credit.amount - authorization_amount, store_credit.currency)).to be_truthy
        end

        it 'adds the new amount to authorized amount' do
          store_credit.authorize(added_authorization_amount, store_credit.currency)
          expect(store_credit.reload.amount_authorized).to eq (authorization_amount + added_authorization_amount)
        end

        context 'originator is present' do
          subject do
            store_credit.authorize(added_authorization_amount, store_credit.currency,
                                   action_originator: originator)
          end

          let(:originator) { create(:refund, amount: 10) }

          it 'records the originator' do
            expect { subject }.to change { Spree::StoreCreditEvent.count }.by(1)
            expect(Spree::StoreCreditEvent.last.originator).to eq originator
          end
        end
      end

      context 'authorization has already happened' do
        let!(:auth_event) { create(:store_credit_auth_event, store_credit: store_credit) }

        before { store_credit.update_attributes(amount_authorized: store_credit.amount) }

        it 'returns true' do
          expect(store_credit.authorize(store_credit.amount, store_credit.currency,
                                        action_authorization_code: auth_event.authorization_code)).to be true
        end
      end
    end

    context 'amount is invalid' do
      it 'returns false' do
        expect(store_credit.authorize(store_credit.amount * 2, store_credit.currency)).to be false
      end
    end
  end

  describe '#validate_authorization' do
    context 'insufficient funds' do
      subject { store_credit.validate_authorization(store_credit.amount * 2, store_credit.currency) }

      it 'returns false' do
        expect(subject).to be false
      end

      it 'adds an error to the model' do
        subject
        text = Spree.t('store_credit_payment_method.insufficient_funds')
        expect(store_credit.errors.full_messages).to include(text)
      end
    end

    context 'currency mismatch' do
      subject { store_credit.validate_authorization(store_credit.amount, 'EUR') }

      it 'returns false' do
        expect(subject).to be false
      end

      it 'adds an error to the model' do
        subject
        text = Spree.t('store_credit_payment_method.currency_mismatch')
        expect(store_credit.errors.full_messages).to include(text)
      end
    end

    context 'valid authorization' do
      subject { store_credit.validate_authorization(store_credit.amount, store_credit.currency) }

      it 'returns true' do
        expect(subject).to be true
      end
    end

    context 'troublesome floats' do
      # 8.21.to_d < 8.21 => true
      subject { store_credit.validate_authorization(store_credit_attrs[:amount], store_credit.currency) }

      let(:store_credit_attrs) { { amount: 8.21 } }

      it 'returns true' do
        expect(subject).to be_truthy
      end
    end
  end

  describe '#capture' do
    let(:authorized_amount) { 10.00 }
    let(:auth_code) { '23-SC-20140602164814476128' }

    before do
      store_credit.update_attributes(amount_authorized: authorized_amount, amount_used: 0.0)
      allow(store_credit).to receive_messages(authorize: true)
    end

    context 'insufficient funds' do
      subject { store_credit.capture(authorized_amount * 2, auth_code, store_credit.currency) }

      it 'returns false' do
        expect(subject).to be false
      end

      it 'adds an error to the model' do
        subject
        text = Spree.t('store_credit_payment_method.insufficient_authorized_amount')
        expect(store_credit.errors.full_messages).to include(text)
      end

      it 'does not update the store credit model' do
        expect { subject }.not_to change { store_credit }
      end
    end

    context 'currency mismatch' do
      subject { store_credit.capture(authorized_amount, auth_code, 'EUR') }

      it 'returns false' do
        expect(subject).to be false
      end

      it 'adds an error to the model' do
        subject
        text = Spree.t('store_credit_payment_method.currency_mismatch')
        expect(store_credit.errors.full_messages).to include(text)
      end

      it 'does not update the store credit model' do
        expect { subject }.not_to change { store_credit }
      end
    end

    context 'valid capture' do
      subject do
        amount = authorized_amount - remaining_authorized_amount
        store_credit.capture(amount, auth_code, store_credit.currency,
                             action_originator: originator)
      end

      let(:remaining_authorized_amount) { 1 }
      let(:originator) { nil }

      it 'returns true' do
        expect(subject).to be_truthy
      end

      it 'updates the authorized amount to the difference between the captured amount and the authorized amount' do
        subject
        expect(store_credit.reload.amount_authorized).to eq remaining_authorized_amount
      end

      it 'updates the used amount to the current used amount plus the captured amount' do
        subject
        expect(store_credit.reload.amount_used).to eq authorized_amount - remaining_authorized_amount
      end

      context 'originator is present' do
        let(:originator) { create(:refund, amount: 10) }

        it 'records the originator' do
          expect { subject }.to change { Spree::StoreCreditEvent.count }.by(1)
          expect(Spree::StoreCreditEvent.last.originator).to eq originator
        end
      end
    end
  end

  describe '#void' do
    subject do
      store_credit.void(auth_code, action_originator: originator)
    end

    let(:auth_code) { '1-SC-20141111111111' }
    let(:store_credit) { create(:store_credit, amount_used: 150.0) }
    let(:originator) { nil }

    context 'no event found for auth_code' do
      it 'returns false' do
        expect(subject).to be false
      end

      it 'adds an error to the model' do
        subject
        text = Spree.t('store_credit_payment_method.unable_to_void', auth_code: auth_code)
        expect(store_credit.errors.full_messages).to include(text)
      end
    end

    context 'capture event found for auth_code' do
      let(:captured_amount) { 10.0 }
      let!(:capture_event) do
        create(:store_credit_auth_event,
               action: Spree::StoreCredit::CAPTURE_ACTION,
               authorization_code: auth_code,
               amount: captured_amount,
               store_credit: store_credit)
      end

      it 'returns false' do
        expect(subject).to be false
      end

      it 'does not change the amount used on the store credit' do
        expect { subject }.not_to change { store_credit.amount_used.to_f }
      end
    end

    context 'auth event found for auth_code' do
      let(:authorized_amount) { 10.0 }
      let!(:auth_event) do
        create(:store_credit_auth_event,
               authorization_code: auth_code,
               amount: authorized_amount,
               store_credit: store_credit)
      end

      it 'returns true' do
        expect(subject).to be true
      end

      it 'returns the capture amount to the store credit' do
        expect { subject }.to change { store_credit.amount_authorized.to_f }.by(-authorized_amount)
      end

      context 'originator is present' do
        let(:originator) { create(:refund, amount: 10) }

        it 'records the originator' do
          expect { subject }.to change { Spree::StoreCreditEvent.count }.by(1)
          expect(Spree::StoreCreditEvent.last.originator).to eq originator
        end
      end
    end
  end

  describe '#credit' do
    subject do
      store_credit.credit(credit_amount, auth_code, currency, action_originator: originator)
    end

    let(:event_auth_code) { '1-SC-20141111111111' }
    let(:amount_used) { 10.0 }
    let(:store_credit) { create(:store_credit, amount_used: amount_used) }
    let!(:capture_event) do
      create(:store_credit_auth_event,
             action: Spree::StoreCredit::CAPTURE_ACTION,
             authorization_code: event_auth_code,
             amount: captured_amount,
             store_credit: store_credit)
    end
    let(:originator) { nil }

    context 'currency does not match' do
      let(:currency) { 'AUD' }
      let(:credit_amount) { 5.0 }
      let(:captured_amount) { 100.0 }
      let(:auth_code) { event_auth_code }

      it 'returns false' do
        expect(subject).to be false
      end

      it 'adds an error message about the currency mismatch' do
        subject
        text = Spree.t('store_credit_payment_method.currency_mismatch')
        expect(store_credit.errors.full_messages).to include(text)
      end
    end

    context 'unable to find capture event' do
      let(:currency) { 'USD' }
      let(:credit_amount) { 5.0 }
      let(:captured_amount) { 100.0 }
      let(:auth_code) { 'UNKNOWN_CODE' }

      it 'returns false' do
        expect(subject).to be false
      end

      it 'adds an error message about the currency mismatch' do
        subject
        text = Spree.t('store_credit_payment_method.unable_to_credit', auth_code: auth_code)
        expect(store_credit.errors.full_messages).to include(text)
      end
    end

    context 'amount is more than what is captured' do
      let(:currency) { 'USD' }
      let(:credit_amount) { 100.0 }
      let(:captured_amount) { 5.0 }
      let(:auth_code) { event_auth_code }

      it 'returns false' do
        expect(subject).to be false
      end

      it 'adds an error message about the currency mismatch' do
        subject
        text = Spree.t('store_credit_payment_method.unable_to_credit', auth_code: auth_code)
        expect(store_credit.errors.full_messages).to include(text)
      end
    end

    context 'amount is successfully credited' do
      let(:currency) { 'USD' }
      let(:credit_amount) { 5.0 }
      let(:captured_amount) { 100.0 }
      let(:auth_code) { event_auth_code }

      context 'credit_to_new_allocation is set' do
        before { Spree::Config[:credit_to_new_allocation] = true }

        it 'returns true' do
          expect(subject).to be true
        end

        it 'creates a new store credit record' do
          expect { subject }.to change { Spree::StoreCredit.count }.by(1)
        end

        it 'does not create a new store credit event on the parent store credit' do
          expect { subject }.not_to change { store_credit.store_credit_events.count }
        end

        context 'credits the passed amount to a new store credit record' do
          before do
            subject
            @new_store_credit = Spree::StoreCredit.last
          end

          it 'does not set the amount used on hte originating store credit' do
            expect(store_credit.reload.amount_used).to eq amount_used
          end

          it 'sets the correct amount on the new store credit' do
            expect(@new_store_credit.amount).to eq credit_amount
          end

          [:user_id, :category_id, :created_by_id, :currency, :type_id].each do |attr|
            it "sets attribute #{attr} inherited from the originating store credit" do
              expect(@new_store_credit.send(attr)).to eq store_credit.send(attr)
            end
          end

          it 'sets a memo' do
            expect(@new_store_credit.memo).to eq "This is a credit from store credit ID #{store_credit.id}"
          end
        end

        context 'originator is present' do
          let(:originator) { create(:refund, amount: 10) }

          it 'records the originator' do
            expect { subject }.to change { Spree::StoreCreditEvent.count }.by(1)
            expect(Spree::StoreCreditEvent.last.originator).to eq originator
          end
        end
      end

      context 'credit_to_new_allocation is not set' do
        it 'returns true' do
          expect(subject).to be true
        end

        it 'credits the passed amount to the store credit amount used' do
          subject
          expect(store_credit.reload.amount_used).to eq (amount_used - credit_amount)
        end

        it 'creates a new store credit event' do
          expect { subject }.to change { store_credit.store_credit_events.count }.by(1)
        end
      end
    end
  end

  describe '#amount_used' do
    context 'amount used is not defined' do
      subject { Spree::StoreCredit.new }

      it 'returns zero' do
        expect(subject.amount_used).to be_zero
      end
    end

    context 'amount used is defined' do
      subject { create(:store_credit, amount_used: amount_used) }

      let(:amount_used) { 100.0 }

      it 'returns the attribute value' do
        expect(subject.amount_used).to eq amount_used
      end
    end
  end

  describe '#amount_authorized' do
    context 'amount authorized is not defined' do
      subject { Spree::StoreCredit.new }

      it 'returns zero' do
        expect(subject.amount_authorized).to be_zero
      end
    end

    context 'amount authorized is defined' do
      subject { create(:store_credit, amount_authorized: amount_authorized) }

      let(:amount_authorized) { 100.0 }

      it 'returns the attribute value' do
        expect(subject.amount_authorized).to eq amount_authorized
      end
    end
  end

  describe '#can_capture?' do
    subject { store_credit.can_capture?(payment) }

    let(:store_credit) { create(:store_credit) }
    let(:payment) { create(:payment, state: payment_state) }

    context 'pending payment' do
      let(:payment_state) { 'pending' }

      it 'returns true' do
        expect(subject).to be true
      end
    end

    context 'checkout payment' do
      let(:payment_state) { 'checkout' }

      it 'returns true' do
        expect(subject).to be true
      end
    end

    context 'void payment' do
      let(:payment_state) { Spree::StoreCredit::VOID_ACTION }

      it 'returns false' do
        expect(subject).to be false
      end
    end

    context 'invalid payment' do
      let(:payment_state) { 'invalid' }

      it 'returns false' do
        expect(subject).to be false
      end
    end

    context 'complete payment' do
      let(:payment_state) { 'completed' }

      it 'returns false' do
        expect(subject).to be false
      end
    end
  end

  describe '#can_void?' do
    subject { store_credit.can_void?(payment) }

    let(:store_credit) { create(:store_credit) }
    let(:payment) { create(:payment, state: payment_state) }

    context 'pending payment' do
      let(:payment_state) { 'pending' }

      it 'returns true' do
        expect(subject).to be true
      end
    end

    context 'remove store credits' do
      let(:payment_state) { :checkout }

      context 'when payment is in checkout and order is not completed' do
        it { is_expected.to be true }
      end

      context 'when order is completed' do
        before { payment.order.update_column(:completed_at, Time.current) }

        it { is_expected.to be false }
      end

      context 'when payment is completed' do
        before { payment.update_column(:state, :completed) }

        it { is_expected.to be false }
      end
    end

    context 'void payment' do
      let(:payment_state) { Spree::StoreCredit::VOID_ACTION }

      it 'returns false' do
        expect(subject).to be false
      end
    end

    context 'invalid payment' do
      let(:payment_state) { 'invalid' }

      it 'returns false' do
        expect(subject).to be false
      end
    end

    context 'complete payment' do
      let(:payment_state) { 'completed' }

      it 'returns false' do
        expect(subject).to be false
      end
    end
  end

  describe '#can_credit?' do
    subject { store_credit.can_credit?(payment) }

    let(:store_credit) { create(:store_credit) }
    let(:payment) { create(:payment, state: payment_state) }

    context 'payment is not completed' do
      let(:payment_state) { 'pending' }

      it 'returns false' do
        expect(subject).to be false
      end
    end

    context 'payment is completed' do
      let(:payment_state) { 'completed' }

      context 'credit is owed on the order' do
        before { allow(payment.order).to receive_messages(payment_state: 'credit_owed') }

        context "payment doesn't have allowed credit" do
          before { allow(payment).to receive_messages(credit_allowed: 0.0) }

          it 'returns false' do
            expect(subject).to be false
          end
        end

        context 'payment has allowed credit' do
          before { allow(payment).to receive_messages(credit_allowed: 5.0) }

          it 'returns true' do
            expect(subject).to be true
          end
        end
      end
    end

    describe '#store_events' do
      context 'create' do
        context 'user has one store credit' do
          subject { create(:store_credit, amount: store_credit_amount) }

          let(:store_credit_amount) { 100.0 }

          it 'creates a store credit event' do
            expect { subject }.to change { Spree::StoreCreditEvent.count }.by(1)
          end

          it 'makes the store credit event an allocation event' do
            expect(subject.store_credit_events.first.action).to eq Spree::StoreCredit::ALLOCATION_ACTION
          end

          it "saves the user's total store credit in the event" do
            expect(subject.store_credit_events.first.user_total_amount).to eq store_credit_amount
          end
        end

        context 'user has multiple store credits' do
          subject { create(:store_credit, user: user, amount: additional_store_credit_amount) }

          let(:store_credit_amount) { 100.0 }
          let(:additional_store_credit_amount) { 200.0 }

          let(:user) { create(:user) }
          let!(:store_credit) { create(:store_credit, user: user, amount: store_credit_amount) }

          it "saves the user's total store credit in the event" do
            amount = store_credit_amount + additional_store_credit_amount
            expect(subject.store_credit_events.first.user_total_amount).to eq amount
          end
        end

        context 'an action is specified' do
          it 'creates an event with the set action' do
            store_credit = build(:store_credit)
            store_credit.action = Spree::StoreCredit::VOID_ACTION
            store_credit.action_authorization_code = '1-SC-TEST'

            expect { store_credit.save! }.to change {
              Spree::StoreCreditEvent.where(action: Spree::StoreCredit::VOID_ACTION).count
            }.by(1)
          end
        end
      end
    end
  end
end
