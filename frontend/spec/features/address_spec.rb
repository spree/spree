require 'spec_helper'

describe 'Address', type: :feature, inaccessible: true do
  stub_authorization!

  let!(:mug) { create(:product, name: 'RoR Mug') }

  before do
    create(:order_with_totals, state: 'cart')

    address = 'order_bill_address_attributes'
    @country_css = "#{address}_country_id"
    @state_select_css = "##{address}_state_id"
    @state_name_css = "##{address}_state_name"
    @state_label_css = '#b_state_label'
    @zipcode_label_css = '#b_zipcode_label'
  end

  context 'store checkout_zone', js: true do
    let!(:store) { create(:store, default: true) }
    let!(:asia_zone) do
      hk = create(:country, name: 'Hong Kong', iso_name: 'HK')
      create(:zone, name: 'Asia', kind: 'country', default_tax: true).tap do |zone|
        zone.members << create(:zone_member, zoneable: hk)
      end
    end

    let!(:eu_vat_zone) do
      denmark = create(:country, name: 'Denmark', iso_name: 'DNK')
      create(:zone, name: 'EU_VAT', kind: 'country', default_tax: true).tap do |zone|
        zone.members << create(:zone_member, zoneable: denmark)
      end
    end

    context 'when store have checkout_zone_id attribute' do
      before do
        store.update!(checkout_zone_id: asia_zone.id)

        add_to_cart(mug) do
          click_link 'Checkout'
        end
      end

      it 'address form contain selected zone' do
        expect(page.find('#order_bill_address_attributes_country_id').text).to eq 'Hong Kong'
      end
    end

    context 'user account', js: true do
      context 'address form in user account' do
        context 'with checkout_zone' do
          before do
            store.update!(checkout_zone_id: asia_zone.id)
          end

          it 'address form contain selected zone' do
            visit spree.new_address_path

            expect(page.find('#address_country_id').text).to eq 'Hong Kong'
          end
        end

        context 'without checkout_zone' do
          before do
            store.update(checkout_zone_id: nil)
            Spree::Config.preference_default(:checkout_zone)
          end

          it 'address form contain selected zone' do
            visit spree.new_address_path

            expect(page.find('#address_country_id').text.split("\n").sort).to eq Spree::Country.pluck(:name).sort
          end
        end
      end
    end

    context 'when checkout_zone is set by preference' do
      before do
        store.update(checkout_zone_id: nil)
        Spree::Config[:checkout_zone] = eu_vat_zone.name

        add_to_cart(mug) do
          click_link 'Checkout'
        end
      end

      it 'address form contain selected zone' do
        expect(page.find('#order_bill_address_attributes_country_id').text).to eq 'Denmark'
      end
    end

    context 'when checkout_zone is not set in store or via preference' do
      before do
        store.update(checkout_zone_id: nil)
        Spree::Config.preference_default(:checkout_zone)

        add_to_cart(mug) do
          click_link 'Checkout'
        end
      end

      it 'return all countries' do
        expect(page.find('#order_bill_address_attributes_country_id').text.split("\n").sort).to eq Spree::Country.pluck(:name).sort
      end
    end
  end

  context 'country requires state', js: true do
    let!(:canada) { create(:country, name: 'Canada', states_required: true, iso: 'CA', zipcode_required: true) }
    let!(:uk) { create(:country, name: 'United Kingdom', states_required: false, iso: 'UK', zipcode_required: true) }

    before { Spree::Config[:default_country_id] = uk.id }

    context 'but has no states in the database' do
      before do
        add_to_cart(mug) do
          click_link 'Checkout'
        end
      end

      it 'shows the state input field' do
        select canada.name, from: @country_css
        expect(page).to have_css(@state_select_css, filter_set: :select, disabled: true, visible: :hidden)
        expect(page).to have_css(@state_name_css, filter_set: :field, disabled: false, visible: :visible)
        expect(page).not_to have_css('label.state-select-label')
      end

      it 'removes state-select-label from label class list' do
        select canada.name, from: @country_css
        expect(page).not_to have_css('label.state-select-label')
      end

      it 'shows placeholder and label text indicating a required field' do
        select canada.name, from: @country_css
        find("input[placeholder='#{Spree.t(:state)} #{Spree.t(:required)}']").set 'Ontario'
        expect(page).to have_css("label#{@state_label_css}", text: Spree.t(:required))
      end
    end

    context 'and has states in database' do
      before do
        create(:state, name: 'Ontario', country: canada)

        add_to_cart(mug) do
          click_link 'Checkout'
        end
      end

      it 'shows the state collection selection' do
        select canada.name, from: @country_css
        expect(page).to have_css(@state_select_css, visible: :visible)
        expect(page).to have_css(@state_name_css, filter_set: :field, disabled: true, visible: :hidden)
      end

      it 'adds state-select-label to the lable class list' do
        select canada.name, from: @country_css
        expect(page).to have_css('label.state-select-label')
      end

      it 'shows the state required indicator in the label' do
        select canada.name, from: @country_css
        expect(page).to have_css("label#{@state_label_css}", text: Spree.t(:required))
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
        expect(page).to have_css(@state_name_css, filter_set: :field, disabled: true, visible: :hidden)
        expect(page).to have_css(@state_select_css, visible: :hidden)
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

  context 'country that requires zipcode', js: true do
    let!(:canada) { create(:country, name: 'Canada', states_required: true, iso: 'CA', zipcode_required: true) }
    let!(:ug) { create(:country, name: 'Uganda', states_required: false, iso: 'UG', zipcode_required: false) }

    before do
      Spree::Config[:default_country_id] = canada.id

      add_to_cart(mug) do
        click_link 'Checkout'
      end
    end

    it 'loads the page with the zipcode field showing required in the label and placeholder' do
      expect(page).to have_css("label#{@zipcode_label_css}", text: Spree.t(:required), visible: :hidden)
      find("input[placeholder='#{Spree.t(:zipcode)} #{Spree.t(:required)}']").set '98378'
      expect(page).to have_css("label#{@zipcode_label_css}", text: Spree.t(:required))
    end

    context 'When the country is changed to one that does not require a zip code' do
      it 'the JS removes the required markers in the label and placeholder text' do
        select ug.name, from: @country_css
        find("input[placeholder='#{Spree.t(:zipcode)}']").set '98378'
        expect(page).to have_css("label#{@zipcode_label_css}", text: Spree.t(:zipcode).upcase)
      end
    end
  end

  context 'country that does not require zipcode', js: true do
    let!(:canada) { create(:country, name: 'Canada', states_required: true, iso: 'CA', zipcode_required: true) }
    let!(:ug) { create(:country, name: 'Uganda', states_required: false, iso: 'UG', zipcode_required: false) }

    before do
      Spree::Config[:default_country_id] = ug.id

      add_to_cart(mug) do
        click_link 'Checkout'
      end
    end

    it 'loads the page without the zipcode field showing required in the label and placeholder' do
      find("input[placeholder='#{Spree.t(:zipcode)}']").set '98378'
      expect(page).to have_css("label#{@zipcode_label_css}", text: Spree.t(:zipcode).upcase)
    end

    context 'When the country is changed to one that does require a zip code' do
      it 'the JS adds the required markers in the label and placeholder text' do
        select canada.name, from: @country_css
        expect(page).to have_css("label#{@zipcode_label_css}", text: Spree.t(:required), visible: :hidden)
        find("input[placeholder='#{Spree.t(:zipcode)} #{Spree.t(:required)}']").set '98378'
        expect(page).to have_css("label#{@zipcode_label_css}", text: Spree.t(:required))
      end
    end
  end
end
