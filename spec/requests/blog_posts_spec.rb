require "rails_helper"

RSpec.describe "BlogPosts", type: :request do
  describe "GET /blog" do
    it "shows published posts" do
      post = create(:blog_post, title: "Ten Tips For A Family Adventure", published_at: 1.day.ago)

      get blog_posts_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(post.title)
    end

    it "does not show a scheduled post before its publish date" do
      post = create(:blog_post, :draft, title: "Not Yet Live Post")

      get blog_posts_path

      expect(response.body).not_to include(post.title)
    end
  end

  describe "GET /blog/:slug" do
    it "shows a published post" do
      post = create(:blog_post, title: "Ten Tips For A Family Adventure", published_at: 1.day.ago)

      get blog_post_path(post)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(post.title)
    end

    it "404s for a post that isn't published yet" do
      post = create(:blog_post, :draft)

      get blog_post_path(post)

      expect(response).to have_http_status(:not_found)
    end
  end
end
