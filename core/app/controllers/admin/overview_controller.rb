# this clas was inspired (heavily) from the mephisto admin architecture

class Admin::OverviewController < Admin::BaseController
  #todo, add rss feed of information that is happening

  def index
    @users = User.all
    #@users = User.find_with_deleted(:all, :order => 'updated_at desc')
#  going to list today's orders, yesterday's orders, older orders
# have a filter / search at the top
    # @orders, @ 
  end

end
