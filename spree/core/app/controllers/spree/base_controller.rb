require 'cancan'

class Spree::BaseController < ApplicationController
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::Store
  include Spree::Core::ControllerHelpers::Locale
  include Spree::Core::ControllerHelpers::Currency
  include Spree::Core::ControllerHelpers::Turbo
end
