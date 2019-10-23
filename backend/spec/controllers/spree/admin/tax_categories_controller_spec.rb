require 'spec_helper'

module Spree
  module Admin
    describe TaxCategoriesController, type: :controller do
      stub_authorization!

      describe 'GET #index' do
        subject { get :index }

        it 'is successful' do
          expect(subject).to be_successful
        end
      end

      describe 'PUT #update' do
        subject { put :update, params: { id: tax_category.id, tax_category: { name: 'Foo', tax_code: 'Bar' } } }

        let(:tax_category) { create :tax_category }

        it 'redirects' do
          expect(subject).to be_redirect
        end

        it 'updates' do
          subject
          tax_category.reload
          expect(tax_category.name).to eq('Foo')
          expect(tax_category.tax_code).to eq('Bar')
        end
      end
    end
  end
end
