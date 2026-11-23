require 'spec_helper'

RSpec.describe Spree::PaymentSessions::Adyen do
  let(:gateway) { create(:adyen_gateway, :configured) }
  let(:session) { create(:adyen_payment_session, payment_method: gateway) }
  let(:result) do
    SpreeAdyen::Result.new(psp_reference: 'PSP0000000000009', result_code: 'Authorised', variant: 'klarna_paynow',
                           amount: session.amount, currency: session.currency, payments_count: 1)
  end

  it 'attaches no source before settlement' do
    expect(session.payment_source_for_settlement).to be_nil
  end

  it 'records the PSP reference and the variant, never the raw report' do
    payment = session.settle_payment!(captured: false, metadata: result.to_h)

    expect(payment.metadata).to eq('adyen_psp_reference' => 'PSP0000000000009', 'adyen_variant' => 'klarna_paynow')
  end

  it "stores another method under the variant's 5.x class" do
    payment = session.settle_payment!(captured: false, metadata: result.to_h)

    expect(payment.source).to be_a(SpreeAdyen::PaymentSources::Klarna)
    expect(payment.source.adyen_variant).to eq('klarna_paynow')
  end

  it 'names the PSP reference as the capture reference' do
    payment = session.settle_payment!(captured: true, metadata: result.to_h)

    expect(session.capture_reference_for_settlement(payment)).to eq('PSP0000000000009')
    expect(payment.capture_events.sole.transaction_id).to eq('PSP0000000000009')
  end

  it 'reads whether it is payable and what it asked Adyen' do
    session.update!(external_data: { 'payable' => true, 'manual_capture' => true })

    expect(session).to be_payable
    expect(session).to be_manual_capture
  end
end
