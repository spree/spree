require 'spec_helper'

describe 'Address', type: :feature, inaccessible: true do
  stub_authorization!

  let(:mug) { create(:product, name: 'RoR Mug') }

  before do
    create(:order_with_totals, state: 'cart')

    address = 'order_bill_address_attributes'
    @country_css = "#{address}_country_id"
    @state_select_css = "##{address}_state_id"
    @state_name_css = "##{address}_state_name"
  end

  context 'country requires state', js: true do
    let!(:canada) { create(:country, name: 'Canada', states_required: true, iso: 'CA') }
    let!(:uk) { create(:country, name: 'United Kingdom', states_required: true, iso: 'UK') }

    before { Spree::Config[:default_country_id] = uk.id }

    context 'but has no state' do
      before do
        add_to_cart(mug) do
          click_link 'Checkout'
        end
      end

      it 'shows the state input field' do
        select canada.name, from: @country_css
        expect(page).to have_css(@state_select_css, visible: :hidden, class: ['!required'])
        expect(page).to have_css(@state_name_css, visible: true, class: ['!hidden', 'required'])
        expect(page).not_to have_css("input#{@state_name_css}[disabled]")
      end
    end

    context 'and has state' do
      before do
        create(:state, name: 'Ontario', country: canada)

        add_to_cart(mug) do
          click_link 'Checkout'
        end
      end

      it 'shows the state collection selection' do
        select canada.name, from: @country_css
        expect(page).to have_css(@state_select_css, visible: true, class: ['!hidden', 'required'])
        expect(page).to have_css(@state_name_css, visible: :hidden, class: ['!required'])
      end
    end

    context 'user changes to country without states required' do
      let!(:france) { create(:country, name: 'France', states_required: false, iso: 'FRA') }

      before do
        add_to_cart(mug) do
          click_link 'Checkout'
        end
      end

      it 'clears the state name' do
        select canada.name, from: @country_css
        page.find(@state_name_css).set('Toscana')

        select france.name, from: @country_css
        expect(page).to have_css(@state_name_css, filter_set: :field, disabled: true, with: '', visible: :hidden, class: ['!hidden', '!required'])
        expect(page).to have_css(@state_select_css, visible: :hidden, class: ['!required'])
      end
    end
  end

  context 'country does not require state', js: true do
    let!(:france) { create(:country, name: 'France', states_required: false, iso: 'FRA') }

    before do
      add_to_cart(mug) do
        click_link 'Checkout'
      end
    end

    it 'shows a disabled state input field' do
      select france.name, from: @country_css
      expect(page).to have_selector(@state_select_css, visible: :hidden)
      expect(page).to have_selector(@state_name_css, visible: :hidden)
    end
  end
end
