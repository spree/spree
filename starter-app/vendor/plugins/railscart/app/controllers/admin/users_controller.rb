# this clas was inspired (heavily) from the mephisto admin architecture

class Admin::UsersController < Admin::BaseController
  
  def index
    @users = User.find(:all, :page => {:size => 15, :current =>params[:page], :first => 1})
  end

  def show
    @user = User.find(params[:id])
  end

  def edit
    if request.post?
      @user = User.find(params[:id])
      if @user.update_attributes(params[:user])
        flash[:notice] = 'User was successfully updated.'
      end
    else
      @user = User.find(params[:id])
    end
  end
  
  def destroy
    @user = User.find(params[:id])
    @user.destroy
    flash[:notice] = "User was successfully deleted."
    redirect_to :action => 'index'
  end

  def new
    if request.post?
      @user = User.new(params[:user])
      if @user.save
        flash[:notice] = 'User was successfully created.'
        redirect_to :action => "index"      
      else
        flash[:error] = "Problem saving user."
      end
    else
      @user = User.new
    end
  end
  
end
