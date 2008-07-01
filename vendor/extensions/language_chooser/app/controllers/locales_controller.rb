class LocalesController < ApplicationController
  resource_controller

  def update
    redirect_to (request.env['HTTP_REFERER'] or root_path)
  end
end
