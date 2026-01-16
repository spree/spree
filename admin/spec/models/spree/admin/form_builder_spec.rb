require 'spec_helper'

RSpec.describe Spree::Admin::FormBuilder do
  let(:template) { ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil) }
  let(:object) { Spree::Price.new(amount: 129.99, currency: 'USD') }
  let(:builder) { described_class.new(:price, object, template, {}) }

  before do
    allow(template).to receive(:error_message_on).and_return('')
  end

  describe '#spree_money_field' do
    context 'with default locale (en)' do
      before do
        I18n.locale = :en
        I18n.backend.store_translations(:en, number: { currency: { format: { separator: '.', delimiter: ',' } } })
      end

      it 'renders a text field with money-field controller' do
        result = builder.spree_money_field(:amount, currency: 'USD', label: false)

        expect(result).to include('data-controller="money-field"')
        expect(result).to include('data-money-field-locale-value="en"')
        expect(result).to include('data-money-field-decimal-separator-value="."')
        expect(result).to include('data-money-field-thousands-separator-value=","')
      end

      it 'formats the value with 2 decimal places' do
        result = builder.spree_money_field(:amount, currency: 'USD', label: false)

        expect(result).to include('value="129.99"')
      end

      it 'includes the currency symbol as append' do
        result = builder.spree_money_field(:amount, currency: 'USD', label: false)

        expect(result).to include('$')
      end

      it 'sets inputmode to decimal' do
        result = builder.spree_money_field(:amount, currency: 'USD', label: false)

        expect(result).to include('inputmode="decimal"')
      end

      it 'includes blur action for formatting' do
        result = builder.spree_money_field(:amount, currency: 'USD', label: false)

        expect(result).to include('blur-&gt;money-field#format')
      end
    end

    context 'with PLN currency' do
      it 'uses currency decimal mark (comma for PLN)' do
        result = builder.spree_money_field(:amount, currency: 'PLN', label: false)

        # PLN uses comma as decimal mark per ISO standard
        expect(result).to include('data-money-field-decimal-separator-value=","')
        expect(result).to include('value="129,99"')
      end
    end

    context 'with EUR currency' do
      it 'uses currency decimal mark (comma for EUR)' do
        result = builder.spree_money_field(:amount, currency: 'EUR', label: false)

        # EUR uses comma as decimal mark per ISO standard
        expect(result).to include('data-money-field-decimal-separator-value=","')
        expect(result).to include('data-money-field-thousands-separator-value="."')
      end
    end

    context 'with nil amount' do
      let(:object) { Spree::Price.new(amount: nil, currency: 'USD') }

      it 'does not include a formatted value' do
        result = builder.spree_money_field(:amount, currency: 'USD', label: false)

        # Should not include a formatted decimal value like "129.99"
        expect(result).not_to match(/value="\d+\.\d+"/)
      end
    end

    context 'with custom append' do
      it 'uses custom append instead of currency symbol' do
        result = builder.spree_money_field(:amount, currency: 'USD', append: 'custom', label: false)

        expect(result).to include('custom')
      end
    end

    context 'with disabled option' do
      it 'renders disabled field' do
        result = builder.spree_money_field(:amount, currency: 'USD', disabled: true, label: false)

        expect(result).to include('disabled="disabled"')
      end
    end
  end
end
