require 'spec_helper'

describe 'spree/checkout/_summary.html.erb', type: :view do
  # Regression spec for #4223
  it 'does not use the @order instance variable' do
    order = build(:order)
    expect do
      render partial: 'spree/checkout/summary', locals: { order: order }
    end.not_to raise_error
  end
end
