require 'spec_helper'

describe 'Products sorting', type: :feature, js: true, retry: 3 do
  let(:store) { Spree::Store.default }

  def wait_for_turbolinks
    expect(page).to have_no_css '.turbolinks-progress-bar'
  end

  def apply_sorting(sort_by)
    dropdown_element = find('div.plp-sort')

    dropdown_element.find('a', match: :first).click unless dropdown_element[:class].include? 'show'
    find('a', text: Spree.t("plp.#{sort_by}")).click
  end

  def products_names
    all('.product-component-name').map(&:text)
  end

  before do
    visit spree.products_path
    random_prices = (1..100).to_a.shuffle.sample(10)
    create_list(:product, 10, stores: [store]).each_with_index do |p, i|
      p.price = random_prices[i]
      p.save
    end
    store.products.reload
  end

  it 'allows sorting products by name (A-Z)' do
    apply_sorting('name_a_z')
    wait_for_turbolinks

    expect(products_names).to eql(store.products.order(name: :asc).pluck(:name))
  end

  it 'allows sorting products by name (Z-A)' do
    apply_sorting('name_z_a')
    wait_for_turbolinks

    expect(products_names).to eql(store.products.order(name: :desc).pluck(:name))
  end

  it 'allows sorting products by newest first' do
    apply_sorting('newest_first')
    wait_for_turbolinks

    expect(products_names).to eql(store.products.order(available_on: :desc).pluck(:name))
  end

  it 'allows sorting products by price (high to low)' do
    apply_sorting('price_high_to_low')
    wait_for_turbolinks

    expect(products_names).to eql(store.products.sort_by(&:price).reverse.map(&:name))
  end

  it 'allows sorting products by price (low to high)' do
    apply_sorting('price_low_to_high')
    wait_for_turbolinks

    expect(products_names).to eql(store.products.sort_by(&:price).map(&:name))
  end
end
