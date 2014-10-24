require 'spec_helper'

module Spree
  module Admin
    describe TaxCategoriesController, :type => :controller do
      stub_authorization!

      describe 'GET #index' do
        subject { spree_get :index }

        it 'should be successful' do
          expect(subject).to be_success
        end
      end

      describe 'PUT #update' do
        let(:tax_category) { create :tax_category }
    
        subject { spree_put :update, {id: tax_category.id, tax_category: { name: 'Foo', tax_code: 'Bar' }}}

        it 'should redirect' do
          expect(subject).to be_redirect
        end

        it 'should update' do
          subject
          tax_category.reload
          expect(tax_category.name).to eq('Foo')
          expect(tax_category.tax_code).to eq('Bar')
        end
      end
    end
  end
end
