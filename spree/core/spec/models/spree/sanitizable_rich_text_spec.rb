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
end
