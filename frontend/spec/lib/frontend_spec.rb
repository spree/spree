require 'spec_helper'

describe Spree do
  describe 'forbiden route', type: :routing do
    it 'serves by home controller' do
      expect(:get => "/forbidden").to route_to("spree/home#forbidden")
    end
  end
end
