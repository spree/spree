require 'spec_helper'

RSpec.describe SpreeStripe::CreateSource do
  subject do
    described_class.new(
      customer: customer,
      owner: order,
      stripe_payment_method_id: source_id,
      stripe_payment_method_details: payment_method_details,
      gateway: gateway,
      stripe_billing_details: billing_details
    ).call
  end

  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:order) { create(:order, store: store, customer: customer) }
  let!(:gateway) { create(:stripe_gateway, store: store) }
  let(:source_id) { 'source_id' }

  let(:billing_details) { Stripe::StripeObject.construct_from(name: 'John Snow') }

  let(:payment_method_details) do
    Stripe::StripeObject.construct_from(
      card: Stripe::StripeObject.construct_from(
        brand: 'mastercard',
        checks: Stripe::StripeObject.construct_from(
          address_line1_check: 'unchecked',
          address_postal_code_check: 'unchecked',
          cvc_check: nil
        ),
        country: 'PL',
        exp_month: 11,
        exp_year: 2035,
        fingerprint: 'FZqjhq46SWprIY8i',
        funding: 'debit',
        installments: nil,
        last4: '3522',
        mandate: nil,
        network: 'mastercard',
        three_d_secure: nil,
        wallet: Stripe::StripeObject.construct_from(
          apple_pay: nil,
          dynamic_last4: '3139',
          type: 'apple_pay'
        )
      ),
      type: 'card'
    )
  end

  describe '#call' do
    context 'when there is no customer' do
      let(:customer) { nil }
      let(:order) { create(:order, store: store, customer: nil) }

      it 'creates a source not assigned to any customer' do
        expect { subject }.to change { Spree::CreditCard.count }.by 1
        expect(subject.customer).to be_nil
      end
    end

    context 'when the customer already has a card with the same profile id' do
      let!(:credit_card) { create(:credit_card, customer: customer, gateway_payment_profile_id: source_id) }

      it 'returns the already created card' do
        expect(subject).to eq(credit_card)
      end
    end

    context 'when the customer has no card yet' do
      let!(:gateway_customer) { create(:gateway_customer, customer: customer, payment_method: gateway) }

      it 'creates a new source' do
        expect { subject }.to change { customer.credit_cards.count }.by 1

        expect(subject.month).to eq 11
        expect(subject.year).to eq 2035
        expect(subject.last_digits).to eq '3522'
        expect(subject.fingerprint).to eq 'FZqjhq46SWprIY8i'
        expect(subject.gateway_payment_profile_id).to eq source_id
        expect(subject.customer).to eq customer
        expect(subject.brand).to eq 'master'
        expect(subject.payment_method).to eq gateway
        expect(subject.gateway_customer).to eq gateway_customer
        expect(subject.gateway_customer_profile_id).to eq gateway_customer.profile_id
        expect(subject.name).to eq 'John Snow'
        expect(subject.metadata).to eq(
          'wallet' => { 'type' => 'apple_pay' },
          'checks' => {
            'address_line1_check' => 'unchecked',
            'address_postal_code_check' => 'unchecked',
            'cvc_check' => nil
          }
        )
      end
    end

    context 'deduplicating the same physical card by fingerprint' do
      let(:source_id) { 'pm_new' }
      let!(:gateway_customer) { create(:gateway_customer, customer: customer, payment_method: gateway) }

      context 'when the same card is presented again with a new gateway_payment_profile_id' do
        let!(:existing_card) do
          create(:credit_card,
                 customer: customer,
                 payment_method: gateway,
                 gateway_payment_profile_id: 'pm_old',
                 fingerprint: 'FZqjhq46SWprIY8i',
                 month: 11,
                 year: 2035,
                 cc_type: 'master')
        end

        it 'reuses the existing card instead of creating a duplicate' do
          expect { subject }.not_to change { Spree::CreditCard.count }
          expect(subject).to eq(existing_card)
        end

        it 'leaves the existing gateway_payment_profile_id untouched' do
          subject
          expect(existing_card.reload.gateway_payment_profile_id).to eq('pm_old')
        end
      end

      context 'when a genuinely different card is presented (different fingerprint, same last4)' do
        let!(:existing_card) do
          create(:credit_card,
                 customer: customer,
                 payment_method: gateway,
                 gateway_payment_profile_id: 'pm_old',
                 fingerprint: 'someOtherFingerprint',
                 month: 11,
                 year: 2035,
                 cc_type: 'master')
        end

        it 'creates a new card' do
          expect { subject }.to change { customer.credit_cards.count }.by 1
        end
      end

      context 'when the same card number is reissued with a new expiry' do
        let!(:existing_card) do
          create(:credit_card,
                 customer: customer,
                 payment_method: gateway,
                 gateway_payment_profile_id: 'pm_old',
                 fingerprint: 'FZqjhq46SWprIY8i',
                 month: 12,
                 year: 2040,
                 cc_type: 'master')
        end

        it 'creates a new card' do
          expect { subject }.to change { customer.credit_cards.count }.by 1
        end
      end

      context 'when the incoming card has no fingerprint' do
        let(:payment_method_details) do
          Stripe::StripeObject.construct_from(
            card: Stripe::StripeObject.construct_from(
              brand: 'mastercard',
              checks: nil,
              exp_month: 11,
              exp_year: 2035,
              fingerprint: nil,
              last4: '3522',
              wallet: nil
            ),
            type: 'card'
          )
        end

        let!(:existing_card) do
          create(:credit_card,
                 customer: customer,
                 payment_method: gateway,
                 gateway_payment_profile_id: 'pm_old',
                 fingerprint: nil,
                 month: 11,
                 year: 2035,
                 cc_type: 'master')
        end

        it 'creates a new card' do
          expect { subject }.to change { customer.credit_cards.count }.by 1
        end
      end
    end

    context 'when the source is klarna' do
      let(:payment_method_details) do
        Stripe::StripeObject.construct_from(
          klarna: Stripe::StripeObject.construct_from(
            payment_method_category: 'pay_in_installments',
            preferred_locale: 'en-US'
          ),
          type: 'klarna'
        )
      end

      it 'creates a Klarna source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Klarna)
      end
    end

    context 'when the source is afterpay_clearpay' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'afterpay_clearpay') }

      it 'creates an AfterPay source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::AfterPay)
      end
    end

    context 'when the source is sepa_debit' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'sepa_debit') }

      it 'creates a SepaDebit source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::SepaDebit)
      end
    end

    context 'when the source is customer_balance' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'customer_balance') }

      it 'creates a BankTransfer source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::BankTransfer)
      end
    end

    context 'when the source is us_bank_account' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'us_bank_account') }

      it 'creates a BankTransfer source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::BankTransfer)
      end
    end

    context 'when the source is p24' do
      let(:payment_method_details) do
        Stripe::StripeObject.construct_from(
          p24: Stripe::StripeObject.construct_from(
            bank: 'ing',
            reference: 'P24-N01-101-101 R751406491',
            verified_name: 'Jenny Rosen'
          ),
          type: 'p24'
        )
      end

      it 'creates a Przelewy24 source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Przelewy24)
        expect(subject.bank).to eq 'ing'
      end
    end

    context 'when the source is alipay' do
      let(:payment_method_details) do
        Stripe::StripeObject.construct_from(
          alipay: Stripe::StripeObject.construct_from(fingerprint: nil, transaction_id: nil),
          type: 'alipay'
        )
      end

      it 'creates an Alipay source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Alipay)
      end
    end

    context 'when the source is affirm' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'affirm') }

      it 'creates an Affirm source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Affirm)
      end
    end

    context 'when the source is ideal' do
      let(:payment_method_details) do
        Stripe::StripeObject.construct_from(
          ideal: Stripe::StripeObject.construct_from(
            bank: 'rabobank',
            bic: 'RABONL2U',
            generated_sepa_debit: nil,
            generated_sepa_debit_mandate: nil,
            iban_last4: '5264',
            verified_name: 'Jenny Rosen'
          ),
          type: 'ideal'
        )
      end

      it 'creates an Ideal source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Ideal)
        expect(subject.bank).to eq 'rabobank'
        expect(subject.last4).to eq '5264'
      end
    end

    context 'when the source is link' do
      let(:payment_method_details) do
        Stripe::StripeObject.construct_from(link: Stripe::StripeObject.new, type: 'link')
      end

      it 'creates a Link source' do
        expect(subject).to be_a(SpreeStripe::PaymentSources::Link)
      end
    end

    context 'when the source is of an unknown type' do
      let(:payment_method_details) { Stripe::StripeObject.construct_from(type: 'some_future_method') }

      it 'creates a generic PaymentSource' do
        expect(subject).to be_a(Spree::PaymentSource)
        expect(subject.gateway_payment_profile_id).to eq source_id
        expect(subject.payment_method).to eq gateway
      end
    end
  end
end
