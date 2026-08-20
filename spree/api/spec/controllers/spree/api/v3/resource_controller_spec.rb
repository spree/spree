require 'spec_helper'

# Unit spec for `Spree::Api::V3::ResourceController#scope` — the base
# scope-resolution shared by every admin/store resource. The shared base
# carries no authorization framework: it scopes to the store (or the parent
# association) and never consults CanCanCan. The admin branch layers
# `accessible_by` on top — see the Admin::ResourceController spec.
RSpec.describe Spree::Api::V3::ResourceController, type: :controller do
  controller(described_class) do
    def model_class
      Spree::TaxCategory
    end

    public :scope
  end

  let(:store) { @default_store || create(:store, default: true) }
  let!(:default_tax_category) { create(:tax_category, name: 'Default', is_default: true) }
  let!(:other_tax_category) { create(:tax_category, name: 'Other') }

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(request).to receive(:method).and_return('GET')
  end

  describe '#scope' do
    it 'returns a model_class relation' do
      expect(controller.scope).to be_a(ActiveRecord::Relation)
      expect(controller.scope.klass).to eq(Spree::TaxCategory)
    end

    it 'does not narrow via accessible_by — authorization is not the base scope''s job' do
      allow_any_instance_of(ActiveRecord::Relation).to receive(:accessible_by).and_wrap_original do |_method, *|
        raise 'accessible_by should not be called by the shared base scope'
      end

      expect(controller.scope.pluck(:id)).to contain_exactly(default_tax_category.id, other_tax_category.id)
    end

    it 'uses the parent association when @parent is present' do
      promotion = create(:promotion)
      controller.instance_variable_set(:@parent, promotion)
      allow(controller).to receive(:parent_association).and_return(:promotion_rules)

      expect(controller.scope.klass).to eq(Spree::PromotionRule)
    end
  end

  # A controller that declares neither must fail loudly on its first write
  # rather than silently permitting a list inferred from the model name.
  describe '#resource_permitted_attributes' do
    it 'raises unless the subclass declares one' do
      expect { controller.send(:resource_permitted_attributes) }.to raise_error(NotImplementedError)
    end
  end

  # Extensions declare extra writable attributes on the model rather than
  # decorating every controller that writes it — see Spree::Base.
  describe '#permitted_attributes' do
    before do
      allow(controller).to receive(:resource_permitted_attributes).and_return([:name])
    end

    it 'is just the resource list when the model declares nothing extra' do
      expect(controller.send(:permitted_attributes)).to eq([:name])
    end

    # Exercises the real extension contract rather than stubbing the reader:
    # an initializer appends to the model's class_attribute.
    it 'appends attributes the model contributes' do
      original = Spree::TaxCategory.additional_permitted_attributes
      Spree::TaxCategory.additional_permitted_attributes += [:brand_id]

      expect(controller.send(:permitted_attributes)).to eq([:name, :brand_id])
    ensure
      Spree::TaxCategory.additional_permitted_attributes = original
    end
  end
end
