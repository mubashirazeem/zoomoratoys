class BlogPostsController < ApplicationController
  def index
    @blog_posts = BlogPost.published.newest_first.with_attached_cover_image
  end

  def show
    @blog_post = BlogPost.published.with_attached_cover_image.find_by!(slug: params[:slug])
  end
end
