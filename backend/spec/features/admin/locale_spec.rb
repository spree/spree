require 'spec_helper'

describe 'setting locale', type: :feature, js: true do
  stub_authorization!
  let!(:stock_location) { create(:stock_location_with_items) }
  let!(:product) { create(:product, name: 'spree t-shirt', price: 20.00) }
  let!(:store) { create(:store) }
  let!(:order) { create(:order, state: 'complete', completed_at: '2011-02-01 12:36:15', number: 'R100', store_id: store.id) }
  let!(:state) { create(:state) }

  before do
    I18n.locale = I18n.default_locale
    I18n.backend.store_translations(:fr,
                                    spree: {
                                      admin: {
                                        tab: { orders: 'Ordres' }
                                      },
                                      listing_orders: 'Ordres'
                                    })
    Spree::Backend::Config[:locale] = 'fr'
  end

  after do
    I18n.locale = I18n.default_locale
    Spree::Backend::Config[:locale] = 'en'
  end

  it 'is in french' do
    visit spree.admin_path
    click_link 'Ordres'
    expect(page).to have_content('Ordres')
  end
end
