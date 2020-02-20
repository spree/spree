require 'spec_helper'

describe 'Products filtering', :js, :caching do
  let!(:taxon) { create :taxon }

  let!(:option_type_1) { create :option_type, name: 'size', presentation: 'Size' }
  let!(:option_value_1_1) { create :option_value, option_type: option_type_1, name: 's', presentation: 'S' }
  let!(:option_value_1_2) { create :option_value, option_type: option_type_1, name: 'm', presentation: 'M' }

  let!(:product_1) { create :product, name: 'First shirt', option_types: [option_type_1] }
  let!(:variant_1_1) { create :variant, product: product_1, option_values: [option_value_1_1] }

  def search_by(text)
    find('.search-icons').click
    fill_in 'keywords', with: "#{text}\n"
  end

  def click_on_filter(filter_name, value:)
    filter_element = find('.plp-filters-card', text: filter_name)
    filter_header_element = filter_element.find('.plp-filters-card-header')

    filter_header_element.click if filter_header_element[:class].include?('collapsed')

    filter_element.click_link(value)
    wait_for_turbolinks
  end

  def wait_for_turbolinks
    expect(page).to have_no_css '.turbolinks-progress-bar'
  end

  def have_selected_filter_with(value:)
    have_css '.plp-overlay-card-item--selected', text: value
  end

  it 'correctly filters Products' do
    visit spree.nested_taxons_path(taxon)

    search_by 'shirt'
    expect(page).to have_content 'First shirt'

    click_on_filter 'Size', value: 'm'
    expect(page).to have_content 'No results'
    expect(page).to have_selected_filter_with(value: 'M')

    click_on_filter 'Size', value: 's'
    expect(page).to have_content 'First shirt'
    expect(page).to have_selected_filter_with(value: 'M')
    expect(page).to have_selected_filter_with(value: 'S')
    expect(current_path).to eq spree.products_path
  end
end
