class PostsController < ResourceController::Base
  actions :all
  
  create.before(:name_post) { @post.body = '...' }
  
  private
    def name_post
      @post.title = 'a great post'
    end
end