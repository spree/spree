require 'spec_helper'

describe Spree::Products::TouchCategoriesJob, type: :job do
  describe '#perform' do
    subject { described_class.perform_now(category_ids, taxonomy_ids) }

    let!(:taxonomy) { create(:taxonomy) }
    let!(:category_1) { create(:taxon, taxonomy: taxonomy) }
    let!(:category_2) { create(:taxon, taxonomy: taxonomy) }
    let!(:other_category) { create(:taxon) }

    let(:category_ids) { [category_1.id, category_2.id] }
    let(:taxonomy_ids) { [taxonomy.id] }

    it 'touches all specified categories' do
      expect { subject }.to change { Spree::Category.where(id: category_ids).pluck(:updated_at) }
    end

    it 'touches all specified taxonomies' do
      expect { subject }.to change { Spree::Taxonomy.where(id: taxonomy_ids).pluck(:updated_at) }
    end

    it 'does not touch other categories' do
      expect { subject }.not_to change { other_category.reload.updated_at }
    end
  end
end
