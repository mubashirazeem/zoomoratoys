require "rails_helper"

RSpec.describe "Admin::BlogPosts", type: :request do
  describe "GET /admin/blog_posts" do
    it "redirects an anonymous visitor to admin sign in" do
      get admin_blog_posts_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a signed-in admin" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "creates a real blog post" do
      expect {
        post admin_blog_posts_path, params: {
          blog_post: {
            title: "Ten Tips For A Family Adventure",
            excerpt: "Quick advice before your next trip.",
            body: "Full body content here.",
            cover_image_key: Category::PLACEHOLDER_KEYS.first,
            published_at: 1.day.from_now
          }
        }
      }.to change(BlogPost, :count).by(1)

      post_record = BlogPost.last
      expect(post_record.title).to eq("Ten Tips For A Family Adventure")
      expect(post_record).not_to be_published
      expect(response).to redirect_to(admin_blog_posts_path)
    end

    it "updates a post" do
      blog_post = create(:blog_post, title: "Old Title")

      patch admin_blog_post_path(blog_post), params: { blog_post: { title: "New Title" } }

      expect(blog_post.reload.title).to eq("New Title")
    end

    it "deletes a post" do
      blog_post = create(:blog_post)

      expect { delete admin_blog_post_path(blog_post) }.to change(BlogPost, :count).by(-1)
    end

    it "rejects unpermitted attributes rather than mass-assigning them" do
      blog_post = create(:blog_post)

      patch admin_blog_post_path(blog_post), params: { blog_post: { title: "Updated", id: 999_999 } }

      expect(blog_post.reload.id).not_to eq(999_999)
      expect(blog_post.title).to eq("Updated")
    end
  end
end
