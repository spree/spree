class LocalesController < ApplicationController

  def update
    redirect_to (request.env['HTTP_REFERER'] or root_path)
  end
end
