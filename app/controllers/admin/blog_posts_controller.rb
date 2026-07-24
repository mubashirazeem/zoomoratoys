# frozen_string_literal: true

class Admin::BlogPostsController < Admin::BaseController
  before_action :set_blog_post, only: [ :edit, :update, :destroy ]

  def index
    @blog_posts = BlogPost.order(published_at: :desc)
  end

  def new
    @blog_post = BlogPost.new(published_at: Time.current)
  end

  def create
    @blog_post = BlogPost.new(blog_post_params)

    if @blog_post.save
      redirect_to admin_blog_posts_path, notice: "Blog post created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @blog_post.update(blog_post_params)
      redirect_to admin_blog_posts_path, notice: "Blog post updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @blog_post.destroy
    redirect_to admin_blog_posts_path, notice: "Blog post deleted."
  end

  private

  # BlogPost#to_param returns the slug (for customer-facing SEO URLs), same
  # gotcha as Product/Category — look up the same way, not by numeric id.
  def set_blog_post
    @blog_post = BlogPost.find_by!(slug: params[:id])
  end

  def blog_post_params
    params.require(:blog_post).permit(
      :title, :excerpt, :body, :cover_image_key, :cover_image, :published_at
    )
  end
end
