class Api::StatesController < Api::BaseController
  resource_controller_for_api :index, :show
  belongs_to :country
end
