require 'spec_helper'

describe Spree::Validations::DbMaximumLengthValidator, :type => :model do
  context 'when Spree::Product' do
    Spree::Product.class_eval do
      # Slug currently has no validation for maximum length
      validates_with Spree::Validations::DbMaximumLengthValidator, field: :slug
    end
    let(:limit) { 255 } # The default limit of db.string.
    let(:product) { create :product }
    let(:slug) { "x" * (limit + 1)}

    before do
      product.slug = slug
    end

    subject { product.valid? }

    it 'should maximum validate slug' do
      subject
      expect(product.errors[:slug]).to include(I18n.t("errors.messages.too_long", count: limit))
    end
  end
end
