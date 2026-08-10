require 'spec_helper'

describe Spree::SanitizableRichText do
  let(:store) { Spree::Store.default || create(:store) }
  let(:product) { create(:product, store: store) }

  it 'sanitizes the description on save' do
    product.update!(description: '<p>safe</p><script>alert(1)</script>')

    expect(product.reload.description).to include('<p>safe</p>')
    expect(product.reload.description).not_to include('<script')
  end

  it 'leaves an already stored raw description alone when an unrelated attribute changes' do
    product.update_columns(description: '<script>alert(1)</script>')

    product.update!(name: 'Renamed')

    expect(product.reload.description).to eq('<script>alert(1)</script>')
  end

  it 'sanitizes translated descriptions' do
    store.update!(supported_locales: 'en,fr')

    product.upsert_translations('fr' => { 'description' => '<p>bonjour</p><script>alert(1)</script>' })

    expect(product.reload.get_field_with_locale(:fr, :description)).not_to include('<script')
  end

  describe '.has_spree_rich_text' do
    it 'exposes the stored markup as field_html' do
      product.update!(description: '<p>Soft <strong>cotton</strong></p>')

      expect(product.reload.description_html).to eq('<p>Soft <strong>cotton</strong></p>')
    end

    it 'reads an empty string rather than nil when unset' do
      expect(create(:product, store: store, description: nil).description_html).to eq('')
    end

    # There is one way to write rich text: the plain attribute. A second setter
    # would be a second spelling of the same thing.
    it 'defines no field_html writer' do
      expect(product).not_to respond_to(:description_html=)
    end
  end
end
