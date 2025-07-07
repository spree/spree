require "spec_helper"

RSpec.describe "Product translations", type: :feature, js: true do
  stub_authorization!

  let(:store) { Spree::Store.default }

  before do
    allow_any_instance_of(Spree::Store).to receive(:supported_locales_list).and_return(['en', 'fr'])

    I18n.backend.store_translations(:fr,
      spree: {
        i18n: {
          language: 'Langue',
          this_file_language: 'Français (FR)'
        },
      }
    )

    visit spree.edit_admin_product_path(product)

    within('#page_actions_dropdown') do
      click_on 'more-actions-link'
      click_on Spree.t(:translations)
    end
  end

  let(:product) { create(:product, name: 'product', stores: [store], meta_title: 'seo title', meta_description: 'meta description') }

  it "allows to translate product" do
    expect(page).to have_field('product_name_fr')

    fill_in :product_name_fr, with: 'French product'
    # fill_in :product_description_fr, with: 'French description'
    fill_in :product_meta_description_fr, with: 'French meta description'
    fill_in :product_meta_title_fr, with: 'French seo title'
    fill_in :product_slug_fr, with: 'french-product-slug'

    click_on Spree.t(:update)

    expect(page).to have_content('Translations successfully saved')

    I18n.with_locale(:en) do
      expect(product.reload.name).to eq('product')
      # expect(product.reload.description).to eq('description')
      expect(product.reload.meta_description).to eq('meta description')
      expect(product.reload.meta_title).to eq('seo title')
      expect(product.reload.slug).to eq('product')
    end

    I18n.with_locale(:fr) do
      expect(product.reload.name).to eq('French product')
      # expect(product.reload.description).to eq('French description')
      expect(product.reload.meta_description).to eq('French meta description')
      expect(product.reload.meta_title).to eq('French seo title')
      expect(product.reload.slug).to eq('french-product-slug')
    end
  end
end
