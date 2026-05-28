require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PromotionsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:promotion) { create(:promotion) }

    it 'returns promotions list' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |p| p['id'] }).to include(promotion.prefixed_id)
    end
  end

  describe 'GET #show' do
    let!(:promotion) { create(:promotion_with_item_adjustment) }

    it 'returns the promotion' do
      get :show, params: { id: promotion.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(promotion.prefixed_id)
      expect(json_response['name']).to eq(promotion.name)
    end
  end

  describe 'POST #create' do
    let(:base_params) { { name: 'Spring Sale', kind: 'automatic' } }

    context 'with basic attributes only' do
      it 'creates a promotion' do
        expect { post :create, params: base_params, as: :json }.to change(Spree::Promotion, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response['name']).to eq('Spring Sale')
        expect(json_response['kind']).to eq('automatic')
      end

      it 'returns 422 without a name' do
        post :create, params: { kind: 'automatic' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with rules' do
      it 'creates a Currency rule with preferences' do
        post :create,
             params: base_params.merge(
               rules: [{ type: 'currency', preferences: { currency: 'EUR' } }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        promotion = Spree::Promotion.find_by_prefix_id(json_response['id'])
        expect(promotion.rules.size).to eq(1)
        rule = promotion.rules.first
        expect(rule).to be_a(Spree::Promotion::Rules::Currency)
        expect(rule.preferred_currency).to eq('EUR')
      end

      it 'creates an ItemTotal rule with multiple preferences' do
        post :create,
             params: base_params.merge(
               rules: [{
                 type: 'item_total',
                 preferences: { amount_min: '50.0', operator_min: 'gte', amount_max: '500.0', operator_max: 'lt' }
               }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        rule = Spree::Promotion.find_by_prefix_id(json_response['id']).rules.first
        expect(rule).to be_a(Spree::Promotion::Rules::ItemTotal)
        expect(rule.preferred_amount_min).to eq(50.0)
        expect(rule.preferred_operator_min).to eq('gte')
        expect(rule.preferred_amount_max).to eq(500.0)
        expect(rule.preferred_operator_max).to eq('lt')
      end

      it 'creates a Product rule with prefixed product_ids on a new promotion' do
        product_a = create(:product)
        product_b = create(:product)

        post :create,
             params: base_params.merge(
               rules: [{
                 type: 'product',
                 preferences: { match_policy: 'any' },
                 product_ids: [product_a.prefixed_id, product_b.prefixed_id]
               }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        promotion = Spree::Promotion.find_by_prefix_id(json_response['id'])
        rule = promotion.rules.first
        expect(rule).to be_a(Spree::Promotion::Rules::Product)
        expect(rule.product_ids).to contain_exactly(product_a.id, product_b.id)
        expect(rule.preferred_match_policy).to eq('any')
      end

      it 'creates a Taxon rule with prefixed category_ids' do
        taxonomy = create(:taxonomy, store: store)
        taxon = create(:taxon, taxonomy: taxonomy)

        post :create,
             params: base_params.merge(
               rules: [{
                 type: 'category',
                 category_ids: [taxon.prefixed_id]
               }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        rule = Spree::Promotion.find_by_prefix_id(json_response['id']).rules.first
        expect(rule).to be_a(Spree::Promotion::Rules::Taxon)
        expect(rule.taxon_ids).to eq([taxon.id])
      end

      it 'creates multiple rules of different types in one request' do
        post :create,
             params: base_params.merge(
               rules: [
                 { type: 'currency', preferences: { currency: 'USD' } },
                 { type: 'first_order' }
               ]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        promotion = Spree::Promotion.find_by_prefix_id(json_response['id'])
        types = promotion.rules.map(&:class)
        expect(types).to contain_exactly(Spree::Promotion::Rules::Currency, Spree::Promotion::Rules::FirstOrder)
      end

      it 'silently ignores rules with an unknown type' do
        post :create,
             params: base_params.merge(
               rules: [
                 { type: 'currency', preferences: { currency: 'USD' } },
                 { type: 'NotARealRule' }
               ]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        promotion = Spree::Promotion.find_by_prefix_id(json_response['id'])
        expect(promotion.rules.size).to eq(1)
        expect(promotion.rules.first).to be_a(Spree::Promotion::Rules::Currency)
      end
    end

    context 'with actions' do
      it 'creates a CreateItemAdjustments action with a FlatRate calculator' do
        post :create,
             params: base_params.merge(
               actions: [{
                 type: 'create_item_adjustments',
                 calculator: {
                   type: 'flat_rate',
                   preferences: { amount: '25.0', currency: 'USD' }
                 }
               }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        action = Spree::Promotion.find_by_prefix_id(json_response['id']).actions.first
        expect(action).to be_a(Spree::Promotion::Actions::CreateItemAdjustments)
        expect(action.calculator).to be_a(Spree::Calculator::FlatRate)
        expect(action.calculator.preferred_amount).to eq(25.0)
        expect(action.calculator.preferred_currency).to eq('USD')
      end

      it 'creates a FreeShipping action without a calculator' do
        post :create,
             params: base_params.merge(
               actions: [{ type: 'free_shipping' }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        action = Spree::Promotion.find_by_prefix_id(json_response['id']).actions.first
        expect(action).to be_a(Spree::Promotion::Actions::FreeShipping)
      end

      it 'creates a CreateAdjustment action with FlatPercentItemTotal calculator' do
        post :create,
             params: base_params.merge(
               actions: [{
                 type: 'create_adjustment',
                 calculator: {
                   type: 'flat_percent_item_total',
                   preferences: { flat_percent: '10.5' }
                 }
               }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        action = Spree::Promotion.find_by_prefix_id(json_response['id']).actions.first
        expect(action.calculator).to be_a(Spree::Calculator::FlatPercentItemTotal)
        expect(action.calculator.preferred_flat_percent).to eq(10.5)
      end
    end

    context 'with rules and actions in the same request' do
      it 'persists both atomically' do
        post :create,
             params: base_params.merge(
               rules: [{ type: 'currency', preferences: { currency: 'USD' } }],
               actions: [{
                 type: 'create_item_adjustments',
                 calculator: { type: 'flat_rate', preferences: { amount: '5.0' } }
               }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        promotion = Spree::Promotion.find_by_prefix_id(json_response['id'])
        expect(promotion.rules.size).to eq(1)
        expect(promotion.actions.size).to eq(1)
      end
    end

    context 'with shorthand type strings' do
      it 'resolves shorthand to the correct rule subclass' do
        post :create,
             params: base_params.merge(
               rules: [{ type: 'currency', preferences: { currency: 'EUR' } }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        promotion = Spree::Promotion.find_by_prefix_id(json_response['id'])
        expect(promotion.rules.first).to be_a(Spree::Promotion::Rules::Currency)
        expect(promotion.rules.first.preferred_currency).to eq('EUR')
      end

      it 'resolves shorthand for rules with overridden api_type' do
        taxonomy = create(:taxonomy, store: store)
        taxon = create(:taxon, taxonomy: taxonomy)

        post :create,
             params: base_params.merge(
               rules: [{ type: 'category', category_ids: [taxon.prefixed_id] }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        rule = Spree::Promotion.find_by_prefix_id(json_response['id']).rules.first
        expect(rule).to be_a(Spree::Promotion::Rules::Taxon)
        expect(rule.taxon_ids).to eq([taxon.id])
      end

      it 'resolves shorthand for actions and calculators' do
        post :create,
             params: base_params.merge(
               actions: [{
                 type: 'create_item_adjustments',
                 calculator: { type: 'flat_rate', preferences: { amount: '12.5' } }
               }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        action = Spree::Promotion.find_by_prefix_id(json_response['id']).actions.first
        expect(action).to be_a(Spree::Promotion::Actions::CreateItemAdjustments)
        expect(action.calculator).to be_a(Spree::Calculator::FlatRate)
        expect(action.calculator.preferred_amount).to eq(12.5)
      end

      it 'exposes shorthand via the rule/action `type` attribute' do
        post :create,
             params: base_params.merge(
               rules: [{ type: 'currency', preferences: { currency: 'USD' } }],
               actions: [{ type: 'free_shipping' }]
             ),
             as: :json

        expect(response).to have_http_status(:created)
        promotion = Spree::Promotion.find_by_prefix_id(json_response['id'])
        expect(promotion.rules.first.class.api_type).to eq('currency')
        expect(promotion.actions.first.class.api_type).to eq('free_shipping')
      end

      it 'rejects unknown shorthand' do
        post :create,
             params: base_params.merge(
               rules: [{ type: 'not_a_real_rule' }]
             ),
             as: :json

        # Unknown shorthand → rule silently dropped (same behavior as unknown class name).
        expect(response).to have_http_status(:created)
        expect(Spree::Promotion.find_by_prefix_id(json_response['id']).rules).to be_empty
      end
    end
  end

  describe 'PATCH #update' do
    let!(:promotion) { create(:promotion_with_item_adjustment) }

    it 'updates basic attributes' do
      patch :update, params: { id: promotion.prefixed_id, name: 'Renamed' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(promotion.reload.name).to eq('Renamed')
    end

    context 'with rules' do
      it 'adds a new rule to an existing promotion' do
        patch :update,
              params: {
                id: promotion.prefixed_id,
                rules: [{ type: 'currency', preferences: { currency: 'GBP' } }]
              },
              as: :json

        expect(response).to have_http_status(:ok)
        promotion.reload
        expect(promotion.rules.size).to eq(1)
        expect(promotion.rules.first.preferred_currency).to eq('GBP')
      end

      it 'updates an existing rule by prefixed id' do
        rule = create(:promotion_rule, promotion: promotion, type: 'Spree::Promotion::Rules::Currency')
        rule.becomes(Spree::Promotion::Rules::Currency).update!(preferred_currency: 'USD')

        patch :update,
              params: {
                id: promotion.prefixed_id,
                rules: [{
                  id: rule.prefixed_id,
                  type: 'currency',
                  preferences: { currency: 'CAD' }
                }]
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(rule.becomes(Spree::Promotion::Rules::Currency).reload.preferred_currency).to eq('CAD')
        expect(promotion.reload.rules.size).to eq(1)
      end

      it 'replaces product_ids on an existing Product rule' do
        rule = Spree::Promotion::Rules::Product.create!(promotion: promotion)
        product_a = create(:product)
        product_b = create(:product)
        rule.products = [product_a]
        rule.save!

        patch :update,
              params: {
                id: promotion.prefixed_id,
                rules: [{
                  id: rule.prefixed_id,
                  type: 'product',
                  product_ids: [product_b.prefixed_id]
                }]
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(rule.reload.product_ids).to eq([product_b.id])
      end

      it 'destroys rules omitted from the payload' do
        rule = Spree::Promotion::Rules::Currency.create!(promotion: promotion, preferred_currency: 'USD')

        patch :update, params: { id: promotion.prefixed_id, rules: [] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(Spree::PromotionRule.where(id: rule.id)).to be_empty
        expect(promotion.reload.rules).to be_empty
      end

      it 'destroys removed rules while keeping the ones explicitly passed' do
        keep = Spree::Promotion::Rules::Currency.create!(promotion: promotion, preferred_currency: 'USD')
        drop = Spree::Promotion::Rules::FirstOrder.create!(promotion: promotion)

        patch :update,
              params: {
                id: promotion.prefixed_id,
                rules: [{ id: keep.prefixed_id, type: 'currency', preferences: { currency: 'USD' } }]
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(promotion.reload.rules.map(&:id)).to eq([keep.id])
        expect(Spree::PromotionRule.where(id: drop.id)).to be_empty
      end
    end

    context 'with actions' do
      it 'swaps the calculator type and persists new preferences' do
        action = promotion.actions.first

        patch :update,
              params: {
                id: promotion.prefixed_id,
                actions: [{
                  id: action.prefixed_id,
                  type: action.class.api_type,
                  calculator: {
                    type: 'percent_on_line_item',
                    preferences: { percent: '7.5' }
                  }
                }]
              },
              as: :json

        expect(response).to have_http_status(:ok)
        action.reload
        expect(action.calculator).to be_a(Spree::Calculator::PercentOnLineItem)
        expect(action.calculator.preferred_percent).to eq(7.5)
      end

      it 'destroys actions omitted from the payload' do
        existing = promotion.actions.first

        patch :update, params: { id: promotion.prefixed_id, actions: [] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(Spree::PromotionAction.where(id: existing.id)).to be_empty
      end

      it 'adds a FreeShipping action alongside an existing one' do
        existing = promotion.actions.first

        patch :update,
              params: {
                id: promotion.prefixed_id,
                actions: [
                  {
                    id: existing.prefixed_id,
                    type: existing.class.api_type,
                    calculator: {
                      type: existing.calculator.class.api_type,
                      preferences: { amount: existing.calculator.preferred_amount.to_s }
                    }
                  },
                  { type: 'free_shipping' }
                ]
              },
              as: :json

        expect(response).to have_http_status(:ok)
        types = promotion.reload.actions.map(&:class)
        expect(types).to include(Spree::Promotion::Actions::FreeShipping)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:promotion) { create(:promotion) }

    it 'destroys the promotion' do
      expect { delete :destroy, params: { id: promotion.prefixed_id }, as: :json }.
        to change(Spree::Promotion, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
