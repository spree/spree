require 'spec_helper'

shared_examples "category loader" do
  it "sets the credit_categories variable to a list of categories sorted by category name " do
    assigns(:credit_categories).should eq [a_credit_category, b_credit_category]
  end
end

shared_examples "prevents changing used store credits" do
  before do
    store_credit.update_attributes(amount_used: 10.0)
  end

  it "raises an error" do
    expect { subject }.to raise_error(Spree::Admin::StoreCreditError)
  end
end

describe Spree::Admin::StoreCreditsController do
  stub_authorization!
  let(:user) { create(:user) }
  let(:admin_user) { create(:admin_user) }

  let!(:b_credit_category) { create(:store_credit_category, name: "B category") }
  let!(:a_credit_category) { create(:store_credit_category, name: "A category") }

  describe "GET index" do

    before { spree_get :index, user_id: user.id }

    context "the user does not have any store credits" do
      it "sets the store_credits variable to an empty list" do
        assigns(:store_credits).should be_empty
      end
    end

    context "the user has store credits" do
      let(:store_credit) { create(:store_credit, user: user) }

      it "sets the store_credits variable to a list containing the store credits" do
        assigns(:store_credits).should eq [store_credit]
      end
    end
  end

  describe "GET new" do
    let!(:store_credit)      { create(:store_credit, category: a_credit_category) }

    before { spree_get :new, user_id: user.id }

    it_behaves_like "category loader"

    it "sets the store_credit variable to a new store credit model" do
      assigns(:store_credit).should_not be_persisted
    end
  end

  describe "POST create" do
    subject { spree_post :create, parameters }

    before  {
      controller.stub(try_spree_current_user: admin_user)
      create(:primary_credit_type)
    }

    context "the passed parameters are valid" do
      let(:parameters) do
        {
          user_id: user.id,
          store_credit: {
            amount: 1.00,
            category_id: a_credit_category.id
          }
        }
      end

      it "redirects to index" do
        subject.should redirect_to spree.admin_user_store_credits_path(user)
      end

      it "creates a new store credit" do
        expect { subject }.to change(Spree::StoreCredit, :count).by(1)
      end

      it "associates the store credit with the user" do
        subject
        user.reload.store_credits.count.should eq 1
      end

      it "assigns the store credit's created by to the current user" do
        subject
        user.reload.store_credits.first.created_by.should eq admin_user
      end

      it 'sets the admin as the store credit event originator' do
        expect { subject }.to change { Spree::StoreCreditEvent.count }.by(1)
        expect(Spree::StoreCreditEvent.last.originator).to eq admin_user
      end
    end

    context "the passed parameters are invalid" do
      let(:parameters) do
        {
          user_id: user.id,
          store_credit: {
            amount: -1.00,
            category_id: a_credit_category.id
          }
        }
      end

      before { subject }

      it "renders the new action" do
        response.should render_template :new
      end

      it_behaves_like "category loader"
    end
  end

  describe "GET edit" do
    let!(:store_credit)      { create(:store_credit, category: a_credit_category) }

    before { spree_get :edit, user_id: user.id, id: store_credit.id }

    it_behaves_like "category loader"

    it "sets the store_credit variable to the persisted store credit" do
      assigns(:store_credit).should eq store_credit
    end
  end

  describe "PUT update" do
    let!(:store_credit) { create(:store_credit, user: user, category: b_credit_category) }

    subject { spree_put :update, parameters }

    before  { controller.stub(try_spree_current_user: admin_user) }

    context "the passed parameters are valid" do
      let(:updated_amount) { 300.0 }

      let(:parameters) do
        {
          user_id: user.id,
          id: store_credit.id,
          store_credit: {
            amount: updated_amount,
            category_id: a_credit_category.id
          }
        }
      end

      context "the store credit has been used" do
        it_behaves_like "prevents changing used store credits"
      end

      context "the store credit has not been used" do
        it "redirects to index" do
          subject.should redirect_to spree.admin_user_store_credits_path(user)
        end

        it "creates a new store credit" do
          expect { subject }.to_not change(Spree::StoreCredit, :count)
        end

        it "assigns the store credit's created by to the current user" do
          subject
          store_credit.reload.created_by.should eq admin_user
        end

        it "updates passed amount" do
          subject
          store_credit.reload.amount.should eq updated_amount
        end

        it "updates passed category" do
          subject
          store_credit.reload.category.should eq a_credit_category
        end

        it "maintains the user association" do
          subject
          store_credit.reload.user.should eq user
        end
      end
    end

    context "the passed parameters are invalid" do
      let(:parameters) do
        {
          user_id: user.id,
          id: store_credit.id,
          store_credit: {
            amount: -1.00,
            category_id: a_credit_category.id
          }
        }
      end

      before { subject }

      it "renders the edit action" do
        response.should render_template :edit
      end

      it_behaves_like "category loader"
    end
  end

  describe "DELETE destroy" do
    let!(:store_credit) { create(:store_credit, user: user, category: b_credit_category) }

    context "the store credit has been used" do
      subject { spree_delete :destroy, user_id: user.id, id: store_credit.id }

      it_behaves_like "prevents changing used store credits"
    end

    context "the destroy is unsuccessful" do
      before do
        Spree::StoreCredit.any_instance.stub(destroy: false)
        subject
      end

      subject { spree_delete :destroy, user_id: user.id, id: store_credit.id }

      it "returns a 422" do
        response.status.should eq 422
      end

      it "returns an error message" do
        response.body.should eq Spree.t("admin.store_credits.unable_to_delete")
      end
    end

    context "html request" do
      subject { spree_delete :destroy, user_id: user.id, id: store_credit.id }

      it "redirects to index" do
        subject.should redirect_to spree.admin_user_store_credits_path(user)
      end

      it "deletes the store credit" do
        expect { subject }.to change(Spree::StoreCredit, :count).by(-1)
      end
    end

    context "js request" do
      subject { spree_delete :destroy, user_id: user.id, id: store_credit.id, format: :js }

      it "returns a 200 status code" do
        subject
        response.code.should eq "200"
      end

      it "deletes the store credit" do
        expect { subject }.to change(Spree::StoreCredit, :count).by(-1)
      end
    end
  end
end
