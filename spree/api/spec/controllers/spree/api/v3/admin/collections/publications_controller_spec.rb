require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Collections::PublicationsController, type: :controller do
  it_behaves_like 'channel publications endpoint', :collection
end
