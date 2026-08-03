require "rails_helper"

RSpec.describe "Admin::PromotionalBanners", type: :request do
  describe "GET /admin/promotional_banners" do
    it "redirects an anonymous visitor to admin sign in" do
      get admin_promotional_banners_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a signed-in admin" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "creates a banner with a photo" do
      photo = fixture_file_upload("sample_product_image.jpg", "image/jpeg")

      expect {
        post admin_promotional_banners_path, params: {
          promotional_banner: {
            title: "Summer Sale", description: "Up to 30% off select scooters.",
            cta_label: "Shop Sale", cta_url: "/shop", position: 0, active: true, image: photo
          }
        }
      }.to change(PromotionalBanner, :count).by(1)

      banner = PromotionalBanner.last
      expect(banner.title).to eq("Summer Sale")
      expect(banner.image).to be_attached
      expect(response).to redirect_to(admin_promotional_banners_path)
    end

    it "creates a banner with no photo — falls back gracefully, not a broken upload" do
      expect {
        post admin_promotional_banners_path, params: {
          promotional_banner: { title: "Coming Soon", position: 0, active: true }
        }
      }.to change(PromotionalBanner, :count).by(1)

      expect(PromotionalBanner.last.image).not_to be_attached
    end

    it "defaults a new banner's position to the end of the existing list" do
      create(:promotional_banner, position: 3)

      get new_admin_promotional_banner_path

      expect(response.body).to include('value="4"')
    end

    it "rejects a button label with no matching link, showing a real error" do
      expect {
        post admin_promotional_banners_path, params: {
          promotional_banner: { title: "Summer Sale", cta_label: "Shop Sale", cta_url: "", position: 0 }
        }
      }.not_to change(PromotionalBanner, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must both be filled in")
    end

    it "updates a banner's text and replaces its photo" do
      banner = create(:promotional_banner, title: "Old Title")
      new_photo = fixture_file_upload("sample_product_image.jpg", "image/jpeg")

      patch admin_promotional_banner_path(banner), params: {
        promotional_banner: { title: "New Title", image: new_photo }
      }

      banner.reload
      expect(banner.title).to eq("New Title")
      expect(banner.image).to be_attached
      expect(response).to redirect_to(admin_promotional_banners_path)
    end

    it "hides a banner from the home page by toggling active off, without deleting it" do
      banner = create(:promotional_banner, active: true)

      patch admin_promotional_banner_path(banner), params: { promotional_banner: { active: false } }

      expect(banner.reload.active?).to be false
    end

    it "deletes a banner" do
      banner = create(:promotional_banner)

      expect { delete admin_promotional_banner_path(banner) }.to change(PromotionalBanner, :count).by(-1)
      expect(response).to redirect_to(admin_promotional_banners_path)
    end
  end
end
