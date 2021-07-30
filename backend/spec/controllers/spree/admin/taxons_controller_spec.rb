require 'spec_helper'

describe Spree::Admin::TaxonsController, type: :controller do
  stub_authorization!

  describe '#remove_icon' do
    let(:store) { Spree::Store.default }
    let!(:taxonomy) { create(:taxonomy, store: store) }
    let!(:taxon) { create(:taxon, taxonomy: taxonomy) }
    let!(:taxon_image) { Spree::TaxonImage.new }
    let!(:image_file) { File.open(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg') }

    before do
      allow_any_instance_of(described_class).to receive(:current_store).and_return(store)
      taxon_image.attachment.attach(io: image_file, filename: 'thinking-cat.jpg', content_type: 'image/jpeg')
      taxon.icon = taxon_image
      taxon.save!
    end

    it 'should remove current store taxon icon' do
      expect(taxon.icon).to eq(taxon_image)

      allow(taxon).to receive :remove_icon
      post :remove_icon, params: { taxonomy_id: taxonomy.id, id: taxon.id }
      taxon.reload

      expect(taxon.icon).to eq(nil)
    end

    context 'when different current store' do
      let!(:second_store) { create(:store) }
      let(:request) { post :remove_icon, params: { taxonomy_id: taxonomy.id, id: taxon.id } }

      before do
        allow_any_instance_of(described_class).to receive(:current_store).and_return(second_store)
      end

      it 'should not find taxonomy' do
        expect { request }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
