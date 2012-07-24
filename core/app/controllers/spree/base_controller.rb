require 'cancan'

class Spree::BaseController < ApplicationController
  include Spree::Core::ControllerHelpers
end
