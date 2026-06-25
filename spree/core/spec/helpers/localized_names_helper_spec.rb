require 'spec_helper'

describe Spree::LocalizedNamesHelper, type: :helper do
  describe '#locale_display_label' do
    it 'renders the localized label inside a display-name span' do
      html = helper.locale_display_label('en')

      expect(html).to have_css('span[data-controller="display-name"]', text: 'EN — English')
      expect(html).to have_css('span[data-display-name-type-value="language"]')
      expect(html).to have_css('span[data-display-name-code-value="en"]')
    end

    it 'returns nil for a blank code' do
      expect(helper.locale_display_label(nil)).to be_nil
    end
  end

  describe '#country_select_options' do
    let(:country) { build(:country, iso: 'US', name: 'United States') }

    it 'returns [label, id] pairs with the localized country option label' do
      options = helper.country_select_options([country])

      expect(options.size).to eq(1)
      label, id = options.first
      expect(label).to include('United States')
      expect(id).to eq(country.id)
    end
  end
end
