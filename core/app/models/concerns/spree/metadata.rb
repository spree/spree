module Spree
  module Metadata
    extend ActiveSupport::Concern

    included do
      store :public_metadata, coder: JSON
      store :private_metadata, coder: JSON
    end
  end
end
