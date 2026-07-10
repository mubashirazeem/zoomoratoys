class BlogPostsController < ApplicationController
  def index
    @blog_posts = BlogPost.newest_first
  end

  def show
    @blog_post = BlogPost.find_by!(slug: params[:slug])
  end
end
