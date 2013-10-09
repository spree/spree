require 'cancan'
require_dependency 'spree/core/controller_helpers/strong_parameters'

class Spree::BaseController < ApplicationController
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::RespondWith
  include Spree::Core::ControllerHelpers::SSL
  include Spree::Core::ControllerHelpers::Common
  include Spree::Core::ControllerHelpers::Search
  include Spree::Core::ControllerHelpers::StrongParameters

  respond_to :html
end

require 'spree/i18n/initializer'