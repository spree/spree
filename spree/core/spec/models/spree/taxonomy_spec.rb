require 'spec_helper'

describe Spree::Taxonomy, type: :model do
  it_behaves_like 'metadata'

  describe 'scopes' do
    describe '.with_matching_name' do
      let!(:taxonomy1) { create(:taxonomy, name: 'Winter 2024') }
      let!(:taxonomy2) { create(:taxonomy, name: 'Winter 2025') }

      it 'returns the taxonomy with the matching name', :aggregate_failures do
        expect(described_class.with_matching_name('WINTER 2024')).to eq([taxonomy1])
        expect(described_class.with_matching_name('Winter 2024')).to eq([taxonomy1])
        expect(described_class.with_matching_name('winter 2024')).to eq([taxonomy1])

        expect(described_class.with_matching_name('WINTER 2025')).to eq([taxonomy2])
        expect(described_class.with_matching_name('Winter 2025')).to eq([taxonomy2])
        expect(described_class.with_matching_name('winter 2025')).to eq([taxonomy2])
      end

      context 'with translations' do
        before do
          I18n.with_locale(:pl) do
            taxonomy1.update!(name: 'Zima 2024')
            taxonomy2.update!(name: 'Zima 2025')
          end
        end

        it 'returns the taxonomy with the matching name', :aggregate_failures do
          I18n.with_locale(:pl) do
            expect(described_class.with_matching_name('ZIMA 2024')).to eq([taxonomy1])
            expect(described_class.with_matching_name('Zima 2024')).to eq([taxonomy1])
            expect(described_class.with_matching_name('zima 2024')).to eq([taxonomy1])

            expect(described_class.with_matching_name('ZIMA 2025')).to eq([taxonomy2])
            expect(described_class.with_matching_name('Zima 2025')).to eq([taxonomy2])
            expect(described_class.with_matching_name('zima 2025')).to eq([taxonomy2])
          end
        end
      end
    end
  end

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
        @taxonomy.update!(name: 'Soft Goods')
        @taxonomy.reload

        expect(@taxonomy.root.reload.name).to eq('Soft Goods')
      end
    end

    context 'when Taxonomy position is updated' do
      it 'does not change the root Taxon name' do
        @taxonomy.update!(position: 2)
        @taxonomy.reload

        expect(@taxonomy.root.name).to eq('Clothing')
        expect(@taxonomy.position).to eq(2)
      end
    end
  end
end
