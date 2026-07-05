require 'spec_helper'

# Unit spec for `Spree::Api::V3::ResourceController#scope` — the base
# scope-resolution method shared by every admin/store resource. The
# new behavior (post-`scope_for` removal in subclasses) infers the
# CanCanCan action from `request.method` and narrows the relation
# via `accessible_by`, but only when there's no `@parent` (nested
# resources defer to their parent's authorization).
RSpec.describe Spree::Api::V3::ResourceController, type: :controller do
  # Minimal subclass — we only need `model_class` and a way to call
  # `scope` from outside.
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
  end

  describe '#scope without @parent' do
    # Each HTTP method should narrow with a different CanCanCan action.
    # We prove that by giving the ability rule a different visible set
    # per action and asserting which slice comes back.
    {
      'GET' => :show,
      'HEAD' => :show,
      'POST' => :create,
      'PATCH' => :update,
      'PUT' => :update,
      'DELETE' => :destroy
    }.each do |http_method, expected_action|
      it "narrows via accessible_by(_, :#{expected_action}) on #{http_method}" do
        ability = Spree::Ability.new(nil)
        ability.cannot :manage, Spree::TaxCategory
        # Only the expected action sees the default record; every other
        # action sees nothing. If the method-to-action mapping is wrong,
        # the wrong slice will be returned.
        ability.can expected_action, Spree::TaxCategory, is_default: true
        allow(controller).to receive(:current_ability).and_return(ability)
        allow(request).to receive(:method).and_return(http_method)

        ids = controller.scope.pluck(:id)

        expect(ids).to contain_exactly(default_tax_category.id)
      end
    end

    it 'raises MethodNotAllowed (405) on unsupported HTTP methods' do
      allow(controller).to receive(:current_ability).and_return(Spree::Ability.new(nil))
      allow(request).to receive(:method).and_return('TRACE')

      expect { controller.scope }.to raise_error(ActionController::MethodNotAllowed)
    end

    it 'returns a model_class relation' do
      allow(controller).to receive(:current_ability).and_return(Spree::Ability.new(nil))
      allow(request).to receive(:method).and_return('GET')

      expect(controller.scope).to be_a(ActiveRecord::Relation)
      expect(controller.scope.klass).to eq(Spree::TaxCategory)
    end
  end

  describe '#scope with @parent' do
    # When loading a nested resource the parent is assumed to have
    # been authorized at `set_parent` time — the per-action narrowing
    # is deliberately skipped so the parent's permission set wins.
    let(:promotion) { create(:promotion) }

    before do
      controller.instance_variable_set(:@parent, promotion)
      allow(controller).to receive(:parent_association).and_return(:promotion_rules)
      # Anything the controller forwards into accessible_by would be a
      # bug now — block it loudly rather than letting the test pass
      # quietly by coincidence.
      allow_any_instance_of(ActiveRecord::Relation).to receive(:accessible_by).and_wrap_original do |_method, *|
        raise 'accessible_by should not be called when @parent is present'
      end
      # `request.method` would matter for the ability branch; assert
      # the branch is skipped regardless of method.
      allow(request).to receive(:method).and_return('DELETE')
    end

    it 'returns the parent association without invoking accessible_by' do
      expect { controller.scope }.not_to raise_error
      expect(controller.scope.klass).to eq(Spree::PromotionRule)
    end
  end
end
