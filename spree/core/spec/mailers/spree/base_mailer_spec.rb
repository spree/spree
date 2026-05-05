require 'spec_helper'

RSpec.describe Spree::BaseMailer, type: :mailer do
  describe '#set_email_locale' do
    let(:mailer) { described_class.new }

    before do
      I18n.locale = :en
      Mobility.locale = :en
    end

    after do
      I18n.locale = :en
      Mobility.locale = :en
    end

    context 'when order has a locale' do
      let(:store) { create(:store, default_locale: 'en', supported_locales: 'en,fr') }
      let(:order) { create(:order_with_line_items, store: store, locale: 'fr') }

      before do
        mailer.instance_variable_set(:@order, order)
      end

      it 'sets I18n.locale and Mobility.locale to order locale' do
        mailer.send(:set_email_locale)

        expect(I18n.locale).to eq(:fr)
        expect(Mobility.locale).to eq(:fr)
      end
    end

    context 'when order has no locale but store has default locale' do
      let(:store) { create(:store, default_locale: 'de', supported_locales: 'en,de') }
      let(:order) { create(:order_with_line_items, store: store) }

      before do
        # Ensure order doesn't have a locale set (factory may set it to store default)
        order.update_column(:locale, nil)
        mailer.instance_variable_set(:@order, order)
      end

      it 'sets I18n.locale and Mobility.locale to store default locale' do
        mailer.send(:set_email_locale)

        expect(I18n.locale).to eq(:de)
        expect(Mobility.locale).to eq(:de)
      end
    end

    context 'when no order is present' do
      let(:store) { create(:store, default_locale: 'it', supported_locales: 'en,it') }

      before do
        mailer.instance_variable_set(:@order, nil)
        mailer.instance_variable_set(:@store, nil)
        allow(mailer).to receive(:current_store).and_return(store)
      end

      it 'sets I18n.locale and Mobility.locale to current store default locale' do
        mailer.send(:set_email_locale)

        expect(I18n.locale).to eq(:it)
        expect(Mobility.locale).to eq(:it)
      end
    end

    context 'when no locale is available' do
      before do
        mailer.instance_variable_set(:@order, nil)
        mailer.instance_variable_set(:@store, nil)
        allow(mailer).to receive(:current_store).and_return(nil)
      end

      it 'does not change I18n.locale or Mobility.locale' do
        mailer.send(:set_email_locale)

        expect(I18n.locale).to eq(:en)
        expect(Mobility.locale).to eq(:en)
      end
    end
  end
end
