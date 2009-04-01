class BonesController < ApplicationController
  def index
    @bones = Bone.find(:all)  
  end
end
