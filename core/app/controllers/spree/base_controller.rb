require 'cancan'

class Spree::BaseController < ApplicationController
  helper 'spree/orders'
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::RespondWith
  include Spree::Core::ControllerHelpers::Common

  respond_to :html
end
