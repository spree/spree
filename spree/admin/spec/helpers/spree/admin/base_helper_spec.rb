require 'spec_helper'

describe Spree::Admin::BaseHelper do
  describe '#format_preference_value' do
    context 'with zone_ids' do
      let!(:zone1) { create(:zone, name: 'North America') }
      let!(:zone2) { create(:zone, name: 'Europe') }

      it 'returns zone names instead of IDs' do
        result = helper.format_preference_value(:zone_ids, [zone1.id.to_s, zone2.id.to_s])
        expect(result).to include('North America')
        expect(result).to include('Europe')
      end

      it 'filters out blank values' do
        result = helper.format_preference_value(:zone_ids, ['', zone1.id.to_s])
        expect(result).to eq('North America')
      end

      it 'returns None for empty array after filtering' do
        result = helper.format_preference_value(:zone_ids, ['', ''])
        expect(result).to eq(Spree.t(:none))
      end
    end

    context 'with user_ids' do
      let!(:user1) { create(:user, email: 'user1@example.com') }
      let!(:user2) { create(:user, email: 'user2@example.com') }

      it 'returns user emails instead of IDs' do
        result = helper.format_preference_value(:user_ids, [user1.id.to_s, user2.id.to_s])
        expect(result).to include('user1@example.com')
        expect(result).to include('user2@example.com')
      end

      it 'filters out blank values' do
        result = helper.format_preference_value(:user_ids, ['', user1.id.to_s])
        expect(result).to eq('user1@example.com')
      end
    end

    context 'with country_id' do
      let!(:country) { create(:country, name: 'United States') }

      it 'returns country name instead of ID' do
        result = helper.format_preference_value(:country_id, country.id)
        expect(result).to eq('United States')
      end

      it 'returns the original value if country not found' do
        result = helper.format_preference_value(:country_id, 999999)
        expect(result).to eq(999999)
      end
    end

    context 'with other preferences' do
      it 'returns Unlimited for blank values' do
        expect(helper.format_preference_value(:max_quantity, nil)).to eq(Spree.t(:unlimited))
        expect(helper.format_preference_value(:max_quantity, '')).to eq(Spree.t(:unlimited))
      end

      it 'returns the value as-is for simple values' do
        expect(helper.format_preference_value(:min_quantity, 10)).to eq(10)
      end

      it 'joins array values with commas' do
        expect(helper.format_preference_value(:tags, %w[a b c])).to eq('a, b, c')
      end
    end
  end

  describe '#spree_time_ago' do
    it 'returns the local time ago with a tooltip' do
      time = Time.zone.parse('2025-10-21 12:00')
      html = helper.spree_time_ago(time)
      expect(html).to include('<time datetime="2025-10-21T12:00')
      expect(html).to include('tooltip-container')
    end

    it 'returns empty string for blank time' do
      expect(helper.spree_time_ago(nil)).to eq('')
    end
  end

  describe '#preference_field' do
    let(:store) { @default_store }
    let(:calculator) { build(:flat_rate_calculator) }
    let(:form) do
      ActionView::Helpers::FormBuilder.new('calculator', calculator, helper, {})
    end

    before do
      allow(helper).to receive(:current_store).and_return(store)
    end

    it 'returns nil when object does not have the preference' do
      expect(helper.preference_field(calculator, form, :nonexistent_key)).to be_nil
    end

    context 'with a currency preference' do
      let!(:usd_market) { create(:market, store: store, currency: 'USD') }
      let!(:eur_market) { create(:market, store: store, currency: 'EUR') }

      it 'renders a select field with supported currencies as options' do
        html = helper.preference_field(calculator, form, :currency)

        expect(html).to have_css('div.form-group')
        expect(html).to have_css('select[name="calculator[preferred_currency]"]')
        expect(html).to have_css('label[for="calculator_preferred_currency"]')
        expect(html).to have_css('option', text: 'USD')
        expect(html).to have_css('option', text: 'EUR')
      end

      it 'sets the correct id on the wrapper div' do
        html = helper.preference_field(calculator, form, :currency)

        expect(html).to have_css('div#spree-calculator-flatrate-preference-currency')
      end

      it 'includes the autocomplete-select data controller' do
        html = helper.preference_field(calculator, form, :currency)

        expect(html).to have_css('select[data-controller="autocomplete-select"]')
      end
    end

    context 'with a boolean preference' do
      it 'renders a checkbox field' do
        html = helper.preference_field(calculator, form, :apply_only_on_full_priced_items)

        expect(html).to have_css('div.form-group.custom-control.form-checkbox')
        expect(html).to have_css('input[type="checkbox"][name="calculator[preferred_apply_only_on_full_priced_items]"]')
      end

      it 'renders the label with custom-control-label class' do
        html = helper.preference_field(calculator, form, :apply_only_on_full_priced_items)

        expect(html).to have_css('label.custom-control-label')
      end

      it 'sets the correct id on the label' do
        html = helper.preference_field(calculator, form, :apply_only_on_full_priced_items)

        expect(html).to have_css('label#spree-calculator-flatrate-preference-apply_only_on_full_priced_items')
      end
    end

    context 'with a decimal preference' do
      it 'renders a number field' do
        html = helper.preference_field(calculator, form, :amount)

        expect(html).to have_css('div.form-group')
        expect(html).to have_css('input[type="number"][name="calculator[preferred_amount]"]')
      end

      it 'sets the correct id on the wrapper div' do
        html = helper.preference_field(calculator, form, :amount)

        expect(html).to have_css('div#spree-calculator-flatrate-preference-amount')
      end

      it 'renders a label for the field' do
        html = helper.preference_field(calculator, form, :amount)

        expect(html).to have_css('label[for="calculator_preferred_amount"]')
      end
    end
  end

  describe '#render_admin_partials' do
    before do
      # Set up test partials
      allow(Rails.application.config.spree_admin).to receive(:product_form_partials).and_return(['spree/admin/products/test_partial'])
    end

    context 'with new naming convention (without _partials suffix)' do
      it 'renders partials for the given section' do
        allow(helper).to receive(:render).with('spree/admin/products/test_partial', {}).and_return('partial content')

        result = helper.render_admin_partials(:product_form)

        expect(result).to eq('partial content')
      end

      it 'passes options to the partials' do
        allow(helper).to receive(:render).with('spree/admin/products/test_partial', { product: 'test' }).and_return('partial with options')

        result = helper.render_admin_partials(:product_form, { product: 'test' })

        expect(result).to eq('partial with options')
      end

      it 'renders multiple partials' do
        allow(Rails.application.config.spree_admin).to receive(:product_form_partials).and_return([
          'spree/admin/products/partial1',
          'spree/admin/products/partial2'
        ])
        allow(helper).to receive(:render).with('spree/admin/products/partial1', {}).and_return('content1')
        allow(helper).to receive(:render).with('spree/admin/products/partial2', {}).and_return('content2')

        result = helper.render_admin_partials(:product_form)

        expect(result).to eq('content1content2')
      end
    end

    context 'with old naming convention (with _partials suffix)' do
      it 'renders partials for the given section (backward compatibility)' do
        allow(helper).to receive(:render).with('spree/admin/products/test_partial', {}).and_return('partial content')

        result = helper.render_admin_partials(:product_form_partials)

        expect(result).to eq('partial content')
      end

      it 'passes options to the partials' do
        allow(helper).to receive(:render).with('spree/admin/products/test_partial', { product: 'test' }).and_return('partial with options')

        result = helper.render_admin_partials(:product_form_partials, { product: 'test' })

        expect(result).to eq('partial with options')
      end
    end

    context 'with empty partials array' do
      it 'returns empty string' do
        allow(Rails.application.config.spree_admin).to receive(:dashboard_analytics_partials).and_return([])

        result = helper.render_admin_partials(:dashboard_analytics)

        expect(result).to eq('')
      end
    end
  end
end
