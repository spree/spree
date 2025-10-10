module Spree
  module UserApiMethods
    extend ActiveSupport::Concern

    include Spree::UserApiAuthentication
  end
end
