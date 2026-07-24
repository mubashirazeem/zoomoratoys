require "rails_helper"

RSpec.describe BlogPost, type: :model do
  it "has a valid factory" do
    expect(build(:blog_post)).to be_valid
  end

  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:excerpt) }
  it { is_expected.to validate_presence_of(:body) }
  it { is_expected.to validate_presence_of(:published_at) }

  it "rejects a duplicate slug" do
    create(:blog_post, slug: "family-adventure-tips")
    duplicate = build(:blog_post, slug: "family-adventure-tips")

    expect(duplicate).not_to be_valid
  end

  it "generates a slug from the title when none is given" do
    post = build(:blog_post, title: "Ten Tips For A Family Adventure", slug: nil)

    post.valid?

    expect(post.slug).to eq("ten-tips-for-a-family-adventure")
  end

  describe "#published?" do
    it "is true once published_at has passed" do
      expect(build(:blog_post, published_at: 1.day.ago)).to be_published
    end

    it "is false for a future publish date" do
      expect(build(:blog_post, :draft)).not_to be_published
    end
  end

  describe ".published" do
    it "includes only posts whose publish date has passed" do
      live = create(:blog_post, published_at: 1.day.ago)
      scheduled = create(:blog_post, :draft)

      expect(BlogPost.published).to contain_exactly(live)
      expect(BlogPost.published).not_to include(scheduled)
    end
  end
end
