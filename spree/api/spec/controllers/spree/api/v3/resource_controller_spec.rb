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

  # build_resource builds through the owner's association so a record carries
  # its tenancy from where it was built. The association is found by asking
  # the reflections which one points at the model, not by inflecting its name.
  describe 'store association resolution' do
    def resolve(model_class)
      reflections = Spree::Store.reflect_on_all_associations(:has_many).select do |reflection|
        !reflection.nested? && (reflection.klass == model_class rescue false)
      end
      return reflections.first&.name if reflections.one?

      conventional = model_class.model_name.element.pluralize.to_sym
      reflections.find { |reflection| reflection.name == conventional }&.name
    end

    it 'resolves a model whose association is the plural of its name' do
      expect(resolve(Spree::Product)).to eq(:products)
      expect(resolve(Spree::PriceList)).to eq(:price_lists)
    end

    # Store#prices goes through variants through products, which Rails makes
    # readonly — building on it raises, so those build on the class.
    it 'declines a doubly-nested has_many through' do
      expect(resolve(Spree::Price)).to be_nil
    end

    # Several associations reach these, including the deprecated twins this
    # release introduced; the conventional name picks the right one.
    it 'breaks a tie with the conventional name' do
      expect(resolve(Spree::Fulfillment)).to eq(:fulfillments)
      expect(resolve(Spree::CustomField)).to eq(:custom_fields)
    end

    it 'resolves an order to orders' do
      expect(resolve(Spree::Order)).to eq(:orders)
    end

    # Global data has no store association at all, so it builds on the class.
    it 'declines a model the store does not own' do
      expect(resolve(Spree::OptionType)).to be_nil
    end
  end
end
