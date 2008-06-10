class LocalesController < ApplicationController

  def update
    redirect_to request.env['HTTP_REFERER']
  end
end
