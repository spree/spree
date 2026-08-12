require 'spec_helper'

# The provider moved out of spree_core at 6.0. Applications name it as a string
# in an initializer, so the old constants keep resolving for one release.
RSpec.describe 'deprecated Spree::SearchProvider constants' do
  it 'resolves the old provider constant to the gem class' do
    expect(Spree::Deprecation).to receive(:warn).with(/SpreeMeilisearch::SearchProvider/)

    expect(Spree::SearchProvider::Meilisearch).to eq(SpreeMeilisearch::SearchProvider)
  end

  it 'resolves the old presenter constant to the gem class' do
    expect(Spree::Deprecation).to receive(:warn).with(/SpreeMeilisearch::ProductPresenter/)

    expect(Spree::SearchProvider::ProductPresenter).to eq(SpreeMeilisearch::ProductPresenter)
  end

  it 'still raises for genuinely unknown constants' do
    expect { Spree::SearchProvider::Nonsense }.to raise_error(NameError)
  end

  it 'registers the gem presenter as the default document builder' do
    expect(Spree::Dependencies.search_product_presenter).to eq('SpreeMeilisearch::ProductPresenter')
  end
end
