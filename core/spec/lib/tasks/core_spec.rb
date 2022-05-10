require 'spec_helper'

describe 'core:activate_products' do
  include_context 'rake'

  let(:product) { create(:product) }

  describe '#prerequisites' do
    it { expect(subject.prerequisites).to include('environment') }
  end

  it 'draft, make_active_at in the past -> active' do
    product.update(status: 'draft', make_active_at: 1.day.ago)
    subject.invoke
    expect(product.reload.status).to eq('active')
  end

  it 'draft, make_active_at in the future -> draft' do
    product.update(status: 'draft', make_active_at: 1.day.from_now)
    subject.invoke
    expect(product.reload.status).to eq('draft')
  end

  it 'archived, make_active_at in the past -> archived' do
    product.update(status: 'archived', make_active_at: 1.day.ago)
    subject.invoke
    expect(product.reload.status).to eq('archived')
  end

  it 'archived, make_active_at in the future -> archived' do
    product.update(status: 'archived', make_active_at: 1.day.from_now)
    subject.invoke
    expect(product.reload.status).to eq('archived')
  end
end

describe 'core:archive_products' do
  include_context 'rake'

  let(:product) { create(:product) }

  describe '#prerequisites' do
    it { expect(subject.prerequisites).to include('environment') }
  end

  it 'draft, discontinue_on in the past -> archived' do
    product.update(status: 'draft', discontinue_on: 1.day.ago)
    subject.invoke
    expect(product.reload.status).to eq('archived')
  end

  it 'draft, discontinue_on in the future -> draft' do
    product.update(status: 'draft', discontinue_on: 1.day.from_now)
    subject.invoke
    expect(product.reload.status).to eq('draft')
  end

  it 'active, discontinue_on in the past -> archived' do
    product.update(status: 'active', discontinue_on: 1.day.ago)
    subject.invoke
    expect(product.reload.status).to eq('archived')
  end

  it 'active, discontinue_on in the future -> active' do
    product.update(status: 'active', discontinue_on: 1.day.from_now)
    subject.invoke
    expect(product.reload.status).to eq('active')
  end
end
