require 'spec_helper'

RSpec.describe SpreeAdyen::Variants do
  it 'maps every method variant to a stored source class' do
    described_class::METHODS.each do |variant, class_name|
      expect(described_class.source_class(variant)).to eq("SpreeAdyen::PaymentSources::#{class_name}".constantize)
    end
  end

  it 'records a variant missing from the table as Unknown, settling as authorized' do
    expect(described_class.source_class('somethingnew')).to eq(SpreeAdyen::PaymentSources::Unknown)
    expect(described_class.captured_at_once?('somethingnew')).to be(false)
  end

  it 'maps card brands, wallet suffixes included' do
    expect(described_class.card_brand('mc')).to eq('master')
    expect(described_class.card_brand('amex_applepay')).to eq('american_express')
    expect(described_class.card_brand('visa_googlepay')).to eq('visa')
    expect(described_class.wallet('visa_applepay')).to eq('apple_pay')
    expect(described_class.wallet('mc_googlepay')).to eq('google_pay')
    expect(described_class.wallet('visa')).to be_nil
  end

  it 'reads cards and card wallets as cards, captured later' do
    %w[visa mc_applepay googlepay applepay scheme].each do |variant|
      expect(described_class.card?(variant)).to be(true)
      expect(described_class.captured_at_once?(variant)).to be(false)
    end
    expect(described_class.card?('klarna')).to be(false)
  end

  it "follows Adyen's per-method pages on which methods take the money at once" do
    expect(described_class.captured_at_once?('ideal')).to be(true)
    expect(described_class.captured_at_once?('blik')).to be(true)
    expect(described_class.captured_at_once?('klarna_paynow')).to be(false)
    expect(described_class.captured_at_once?('sepadirectdebit')).to be(false)
    expect(described_class.captured_at_once?('scalapay_3x')).to be(false)
  end

  it 'marks the methods Adyen holds for a capture request whatever the account captures' do
    %w[klarna klarna_paylater klarna_account riverty affirm].each do |variant|
      expect(described_class.held_for_capture?(variant)).to be(true)
    end
    %w[visa mc_applepay afterpaytouch scalapay_3x ideal somethingnew].each do |variant|
      expect(described_class.held_for_capture?(variant)).to be(false)
    end
  end

  it 'names each source class' do
    expect(described_class.display_name('Bancontact')).to eq('Bancontact')
    expect(described_class.display_name('Ideal')).to eq('iDEAL')
  end
end
