require 'spec_helper'

describe 'Products filtering', :js do
  let!(:taxon) { create :taxon }

  let!(:size) { create :option_type, name: 'size', presentation: 'Size' }
  let!(:s_size) { create :option_value, option_type: size, name: 's', presentation: 'S' }
  let!(:m_size) { create :option_value, option_type: size, name: 'm', presentation: 'M' }

  let!(:color) { create :option_type, name: 'color', presentation: 'Color' }
  let!(:green_color) { create :option_value, option_type: color, name: 'green', presentation: 'Green' }

  let!(:manufacturer) { create :property, name: 'manufacturer', presentation: 'Manufacturer', filterable: true }
  let!(:wilson_manufacturer) { create :product_property, value: 'Wilson', property: manufacturer }

  let!(:brand) { create :property, name: 'brand', presentation: 'Brand', filterable: true }
  let!(:zeta_brand) { create :product_property, value: 'Zeta', property: brand }
  let!(:alpha_brand) { create :product_property, value: 'Alpha', property: brand }

  let!(:property_3) { create :property, name: 'collection', presentation: 'Collection', filterable: true }

  let!(:product_1) { create :product, name: 'First shirt', option_types: [size, color], product_properties: [zeta_brand], taxons: [taxon] }
  let!(:variant_1_1) { create :variant, product: product_1, option_values: [s_size, green_color] }

  let!(:product_2) { create :product, name: 'Second shirt', option_types: [size], product_properties: [wilson_manufacturer, alpha_brand], taxons: [taxon] }
  let!(:variant_2_1) { create :variant, product: product_2, option_values: [m_size] }

  def visit_taxons_page(taxon)
    visit spree.nested_taxons_path(taxon)
  end

  def change_currency_to(currency)
    find('.internationalization-options').click
    select currency, from: 'switch_to_currency'
  end

  def search_by(text)
    find('.search-icons').click
    fill_in 'keywords', with: "#{text}\n"
  end

  def click_on_filter(filter_name, value: nil)
    filter_element = find('.plp-filters-card', text: filter_name)
    filter_header_element = filter_element.find('.plp-filters-card-header')

    filter_header_element.click if filter_header_element[:class].include?('collapsed')

    if value.present?
      filter_element.click_link(value)
      wait_for_turbolinks
    end
  end

  def wait_for_turbolinks
    expect(page).to have_no_css '.turbolinks-progress-bar'
  end

  def have_selected_filter_with(value:)
    have_css '.plp-overlay-card-item--selected', text: value
  end

  def have_filter_with(value:)
    have_css '.plp-overlay-card-item', text: value.upcase
  end

  def expect_working_filters_clearing
    click_on 'CLEAR ALL'
    expect(page).to have_content 'First shirt'
    expect(page).to have_content 'Second shirt'
    expect(page).not_to have_css('.plp-overlay-card-item--selected')
  end

  def filters
    find('#plp-filters-accordion')
  end

  it 'correctly filters Products' do
    visit spree.nested_taxons_path(taxon)

    expect(page).not_to have_content('CLEAR ALL')

    search_by 'shirt'
    expect(page).to have_content 'First shirt'
    expect(page).to have_content 'Second shirt'

    click_on_filter 'Size', value: 'm'
    expect(page).not_to have_content 'First shirt'
    expect(page).to have_content 'Second shirt'
    expect(page).to have_selected_filter_with(value: 'M')

    click_on_filter 'Size', value: 's'
    expect(page).to have_content 'First shirt'
    expect(page).to have_content 'Second shirt'
    expect(page).to have_selected_filter_with(value: 'M')
    expect(page).to have_selected_filter_with(value: 'S')

    click_on_filter 'Manufacturer', value: 'Wilson'
    expect(page).not_to have_content 'First shirt'
    expect(page).to have_content 'Second shirt'
    expect(page).to have_selected_filter_with(value: 'WILSON')

    click_on_filter 'Brand', value: 'Zeta'
    expect(page).to have_content 'No results'
    expect(page).to have_selected_filter_with(value: 'WILSON')
    expect(page).to have_selected_filter_with(value: 'ZETA')

    click_on_filter 'Brand', value: 'Alpha'
    expect(page).not_to have_content 'First shirt'
    expect(page).to have_content 'Second shirt'
    expect(page).to have_selected_filter_with(value: 'WILSON')
    expect(page).to have_selected_filter_with(value: 'ZETA')
    expect(page).to have_selected_filter_with(value: 'ALPHA')

    click_on_filter 'Price'
    fill_in "$ #{Spree.t(:min)}", with: '19'
    fill_in "$ #{Spree.t(:max)}", with: '20'
    click_on 'DONE'
    expect(page).to have_content 'Second shirt'

    expect_working_filters_clearing

    click_on_filter 'Price', value: '$50 - $100'
    expect(page).to have_content 'No results'

    expect_working_filters_clearing

    expect(current_path).to eq spree.products_path
  end

  context 'option type filters' do
    it 'displays filterable option types' do
      visit spree.nested_taxons_path(taxon)

      %w[Size Color].each do |option_type_name|
        expect(filters).to have_content(option_type_name)
      end
    end

    it 'does not display unfilterable option types' do
      color.update!(filterable: false)
      visit spree.nested_taxons_path(taxon)

      expect(filters).not_to have_content('Color')
    end
  end

  context 'property filters' do
    it 'displays filterable properties' do
      visit spree.nested_taxons_path(taxon)

      %w[Manufacturer Brand].each do |property_name|
        expect(filters).to have_content(property_name)
      end
    end

    it 'does not display unfilterable properties' do
      brand.update!(filterable: false)
      visit spree.nested_taxons_path(taxon)

      expect(filters).not_to have_content('Brand')
    end

    it 'does not display properties that do not have values' do
      visit spree.nested_taxons_path(taxon)

      expect(filters).not_to have_content('Collection')
    end

    it 'shows products that match property filter' do
      visit spree.products_path

      click_on_filter 'Brand', value: 'Alpha'

      expect(page).not_to have_content('First shirt')
      expect(page).to have_content('Second shirt')
    end
  end

  context 'with cached filters' do
    context 'when after visiting products page new filters were added or deleted' do
      let(:jersey_manufacturer) { create(:product_property, value: 'Jerseys', property: manufacturer) }
      let(:beta_brand) { create(:product_property, value: 'Beta', property: brand) }

      let(:xl_size) { create(:option_value, option_type: size, name: 'xl', presentation: 'XL') }
      let!(:variant_1_2) { create(:variant, product: product_1, option_values: [green_color]) }

      it 'correctly displays filterable properties' do
        visit_taxons_page(taxon)

        click_on 'Manufacturer'
        expect(page).to have_filter_with(value: 'Wilson')

        click_on 'Brand'
        expect(page).to have_filter_with(value: 'Zeta')
        expect(page).to have_filter_with(value: 'Alpha')

        product_1.product_properties << jersey_manufacturer
        product_2.product_properties << beta_brand

        visit_taxons_page(taxon)

        click_on 'Manufacturer'
        expect(page).to have_filter_with(value: 'Wilson')
        expect(page).to have_filter_with(value: 'Jerseys')

        click_on 'Brand'
        expect(page).to have_filter_with(value: 'Zeta')
        expect(page).to have_filter_with(value: 'Alpha')
        expect(page).to have_filter_with(value: 'Beta')
      end

      it 'correctly displays filterable options' do
        visit_taxons_page(taxon)

        click_on 'Size'
        expect(page).to have_filter_with(value: 'S')
        expect(page).to have_filter_with(value: 'M')
        expect(page).not_to have_filter_with(value: 'XL')

        variant_1_2.update(option_values: [green_color, xl_size])

        visit_taxons_page(taxon)

        click_on 'Size'
        expect(page).to have_filter_with(value: 'S')
        expect(page).to have_filter_with(value: 'M')
        expect(page).to have_filter_with(value: 'XL')

        variant_1_2.update(option_values: [green_color])

        visit_taxons_page(taxon)

        click_on 'Size'
        expect(page).to have_filter_with(value: 'S')
        expect(page).to have_filter_with(value: 'M')
        expect(page).not_to have_filter_with(value: 'XL')
      end
    end

    context 'when switching between currencies' do
      let(:eur) { 'EUR' }

      let!(:gamma_brand) { create(:product_property, value: 'Gamma', property: brand) }
      let!(:xl_size) { create(:option_value, option_type: size, name: 'xl', presentation: 'XL') }

      let!(:product_3) { create(:product, name: '3rd shirt', product_properties: [gamma_brand], taxons: [taxon], currency: eur) }
      let!(:variant_3) { create(:variant, product: product_3, currency: eur, option_values: [xl_size]) }

      it 'correctly displays filterable properties' do
        visit_taxons_page(taxon)

        click_on 'Manufacturer'
        expect(page).to have_filter_with(value: 'Wilson')

        click_on 'Brand'
        expect(page).to have_filter_with(value: 'Zeta')
        expect(page).to have_filter_with(value: 'Alpha')

        change_currency_to(eur)

        expect(page).not_to have_content('Manufacturer')

        click_on 'Brand'
        expect(page).to have_filter_with(value: 'Gamma')
        expect(page).not_to have_filter_with(value: 'Zeta')
        expect(page).not_to have_filter_with(value: 'Alpha')
      end

      it 'correctly displays filterable options' do
        visit_taxons_page(taxon)

        expect(page).to have_content('Color')

        click_on 'Size'
        expect(page).to have_filter_with(value: 'S')
        expect(page).to have_filter_with(value: 'M')

        change_currency_to(eur)

        expect(page).not_to have_content('Color')

        click_on 'Size'
        expect(page).to have_filter_with(value: 'XL')
        expect(page).not_to have_filter_with(value: 'S')
        expect(page).not_to have_filter_with(value: 'M')
      end
    end

    context 'when switching between taxons' do
      let!(:other_taxon) { create(:taxon) }

      let!(:xl_size) { create(:option_value, option_type: size, name: 'xl', presentation: 'XL') }
      let!(:gamma_brand) { create(:product_property, value: 'Gamma', property: brand) }

      let!(:product_3) { create(:product, name: '3rd shirt', product_properties: [gamma_brand], taxons: [other_taxon]) }
      let!(:variant_3) { create(:variant, product: product_3, option_values: [xl_size]) }

      let!(:wannabe_manufacturer) { create(:product_property, value: 'Wannabe', property: manufacturer) }
      let!(:product_4) { create(:product, name: '4th shirt', product_properties: [wannabe_manufacturer], taxons: [other_taxon]) }

      it 'correctly displays filterable properties' do
        visit_taxons_page(taxon)

        click_on 'Manufacturer'
        expect(page).to have_filter_with(value: 'Wilson')

        click_on 'Brand'
        expect(page).to have_filter_with(value: 'Zeta')
        expect(page).to have_filter_with(value: 'Alpha')

        visit_taxons_page(other_taxon)

        click_on 'Manufacturer'
        expect(page).to have_filter_with(value: 'Wannabe')
        expect(page).not_to have_filter_with(value: 'Wilson')

        click_on 'Brand'
        expect(page).to have_filter_with(value: 'Gamma')
        expect(page).not_to have_filter_with(value: 'Alpha')
        expect(page).not_to have_filter_with(value: 'Zeta')
      end

      it 'correctly displays filterable options' do
        visit_taxons_page(taxon)

        expect(page).to have_content('Color')

        click_on 'Size'
        expect(page).to have_filter_with(value: 'S')
        expect(page).to have_filter_with(value: 'M')

        visit_taxons_page(other_taxon)

        expect(page).not_to have_content('Color')

        click_on 'Size'
        expect(page).to have_filter_with(value: 'XL')
        expect(page).not_to have_filter_with(value: 'S')
        expect(page).not_to have_filter_with(value: 'M')
      end
    end

    context 'when after visiting products page new products were added to the same taxon' do
      let!(:material) { create(:property, :material, filterable: true) }
      let!(:cotton_material) { create(:product_property, value: 'Cotton', property: material) }

      let!(:xl_size) { create(:option_value, option_type: size, name: 'xl', presentation: 'XL') }

      it 'correctly displays filterable properties' do
        visit_taxons_page(taxon)

        click_on 'Manufacturer'
        expect(page).to have_filter_with(value: 'Wilson')

        click_on 'Brand'
        expect(page).to have_filter_with(value: 'Zeta')
        expect(page).to have_filter_with(value: 'Alpha')

        create(:product, name: '3rd shirt', product_properties: [cotton_material], taxons: [taxon])

        visit_taxons_page(taxon)

        click_on 'Material'
        expect(page).to have_filter_with(value: 'Cotton')
      end

      it 'correctly displays filterable options' do
        visit_taxons_page(taxon)

        expect(page).to have_content('Color')

        click_on 'Size'
        expect(page).to have_filter_with(value: 'S')
        expect(page).to have_filter_with(value: 'M')

        product = create(:product, name: '3rd shirt', taxons: [taxon])
        create(:variant, product: product, option_values: [xl_size])

        visit_taxons_page(taxon)

        click_on 'Size'
        expect(page).to have_filter_with(value: 'XL')
      end
    end
  end
end
