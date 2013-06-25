require 'cancan'

class Spree::BaseController < ApplicationController
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::RespondWith
  include Spree::Core::ControllerHelpers::SSL
  include Spree::Core::ControllerHelpers::Common

  respond_to :html
end

require 'spree/i18n/initializer'
