require 'spec_helper'

describe Spree::Products::TouchCategoriesJob, type: :job do
  describe '#perform' do
    subject { described_class.perform_now(category_ids) }

    let!(:category_1) { create(:category) }
    let!(:category_2) { create(:category) }
    let!(:other_category) { create(:category) }

    let(:category_ids) { [category_1.id, category_2.id] }

    it 'touches all specified categories' do
      expect { subject }.to change { Spree::Category.where(id: category_ids).pluck(:updated_at) }
    end

    it 'does not touch other categories' do
      expect { subject }.not_to change { other_category.reload.updated_at }
    end

    it 'accepts the legacy taxonomy_ids argument from jobs enqueued before 6.0' do
      expect {
        described_class.perform_now(category_ids, [1, 2])
      }.to change { Spree::Category.where(id: category_ids).pluck(:updated_at) }
    end
  end
end
