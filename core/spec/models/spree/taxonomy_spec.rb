require 'spec_helper'

describe Spree::Taxonomy, type: :model do
  it_behaves_like 'metadata'

  context '#destroy' do
    before do
      @taxonomy = create(:taxonomy)
      @root_taxon = @taxonomy.root
      @child_taxon = create(:taxon, taxonomy_id: @taxonomy.id, parent: @root_taxon)
    end

    it 'destroys all associated taxons' do
      @taxonomy.destroy
      expect { Spree::Taxon.find(@root_taxon.id) }.to raise_error(ActiveRecord::RecordNotFound)
      expect { Spree::Taxon.find(@child_taxon.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#set_root_taxon_name' do
    before do
      @taxonomy = create(:taxonomy, name: 'Clothing')
      @taxonomy.reload
    end

    context 'when Taxonomy is created' do
      it 'sets the root Taxonomy name to match' do
        expect(@taxonomy.root.name).to eq('Clothing')
      end
    end

    context 'when Taxonomy name is updated' do
      it 'changes the root Taxon name to match' do
        @taxonomy.update(name: 'Soft Goods')
        @taxonomy.save!
        @taxonomy.reload

        expect(@taxonomy.root.name).to eq('Soft Goods')
      end
    end

    context 'when Taxonomy position is updated' do
      it 'does not change the root Taxon name' do
        @taxonomy.update(position: 2)
        @taxonomy.save!
        @taxonomy.reload

        expect(@taxonomy.root.name).to eq('Clothing')
        expect(@taxonomy.position).to eq(2)
      end
    end
  end
end
