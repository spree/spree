require 'spec_helper'

# 5.x wrote these class names into `type` columns, so each must keep loading.
RSpec.describe 'SpreeAdyen::PaymentSources stored names' do
  let(:stored) do
    %w[
      AchDirectDebit Affirm Afterpay Alipay AlipayHk Alma Ancv Atome Bacs Bancontact BankTransfer Benefit Billie
      Bizum Blik Boleto CashAppAfterpay Cashapp Clearpay Dana Doku Duitnow Eps Fastlane Fpx Gcash GiftCards Giropay
      Grabpay Ideal Klarna Oney OnlineBankingCzechRepublic OnlineBankingPoland PayByBank Paypal Paypo Paysafecard
      RatePayDirectDebit Riverty SamsungPay Scalapay SepaDirectDebit Trustly WechatPay Unknown
    ]
  end

  # Classes 5.x shipped but never wrote a row for.
  let(:never_stored) do
    %w[
      ApplePay Bcmc BcmcMobile EbankingFi EftDirectdebitCa EftposAustralia Elo Givex GopayWallet GrabpayPaylater
      Hipercard Kakaopay KcpNaverpay
    ]
  end

  it 'declares all 46 stored names as subclasses of the base' do
    expect(stored.size).to eq(46)
    stored.each do |name|
      expect("SpreeAdyen::PaymentSources::#{name}".constantize.superclass).to eq(SpreeAdyen::PaymentSources::Base)
    end
  end

  it 'ports none of the 13 names 5.x never wrote' do
    never_stored.each do |name|
      expect(SpreeAdyen::PaymentSources.const_defined?(name, false)).to be(false)
    end
  end

  it 'loads a row written under a stored name, with its display name' do
    payment_method = create(:adyen_gateway)
    source = SpreeAdyen::PaymentSources::Klarna.create!(payment_method: payment_method, adyen_variant: 'klarna_paynow')

    loaded = Spree::PaymentSource.find(source.id)
    expect(loaded).to be_a(SpreeAdyen::PaymentSources::Klarna)
    expect(loaded.adyen_variant).to eq('klarna_paynow')
    expect(loaded.class.display_name).to eq('Klarna')
  end

  it 'keeps an unsaved card on a source that is not a saved card' do
    card = SpreeAdyen::PaymentSources::Card.create!(payment_method: create(:adyen_gateway), brand: 'visa', last_digits: '1111')

    expect(card.reload).to have_attributes(brand: 'visa', last_digits: '1111')
    expect(card).not_to be_a(Spree::CreditCard)
  end
end
