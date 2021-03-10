require 'spec_helper'

describe Spree::Admin::TaxonsController, type: :controller do
  stub_authorization!

  describe '#remove_icon' do
    let!(:taxonomy) { create(:taxonomy) }
    let!(:taxon) { create(:taxon, taxonomy: taxonomy) }
    let!(:taxon_image) { Spree::TaxonImage.new }
    let!(:image_file) { File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg') }

    before do
      taxon_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      taxon.icon = taxon_image
      taxon.save!
    end

    it 'removes taxon icon' do
      expect(taxon.icon).to eq(taxon_image)

      allow(taxon).to receive :remove_icon
      post :remove_icon, params: { taxonomy_id: taxonomy.id, id: taxon.id }
      taxon.reload

      expect(taxon.icon).to eq(nil)
    end
  end
end
