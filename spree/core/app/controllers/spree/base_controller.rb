require 'cancan'
require_dependency 'spree/core/controller_helpers/strong_parameters'

class Spree::BaseController < ApplicationController
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::Store
  include Spree::Core::ControllerHelpers::StrongParameters
  include Spree::Core::ControllerHelpers::Locale
  include Spree::Core::ControllerHelpers::Currency
  include Spree::Core::ControllerHelpers::Turbo
end
