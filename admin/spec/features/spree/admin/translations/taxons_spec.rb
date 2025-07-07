require "spec_helper"

RSpec.describe "Taxon translations", type: :feature, js: true do
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

    visit spree.edit_admin_taxonomy_taxon_path(taxon.taxonomy, taxon.id)

    within('#page_actions_dropdown') do
      click_on 'more-actions-link'
      click_on Spree.t(:translations)
    end
  end

  let(:taxonomy) { create(:taxonomy, store: store) }
  let(:taxon) { create(:taxon, name: 'taxon') }

  it "allows to translate taxon" do
    expect(page).to have_field('taxon_name_fr')

    fill_in :taxon_name_fr, with: 'French taxon'
    fill_in_rich_text_area 'taxon_description_fr', with: 'French description'

    click_on Spree.t(:update)

    expect(page).to have_content('Translations successfully saved')

    I18n.with_locale(:en) do
      expect(taxon.reload.name).to eq('taxon')
    end

    I18n.with_locale(:fr) do
      expect(taxon.reload.name).to eq('French taxon')
      expect(taxon.reload.description.to_plain_text).to eq('French description')
    end
  end
end
