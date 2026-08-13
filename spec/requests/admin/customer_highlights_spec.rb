require "rails_helper"

RSpec.describe "Admin::CustomerHighlights", type: :request do
  describe "GET /admin/customer_highlights" do
    it "redirects an anonymous visitor to admin sign in" do
      get admin_customer_highlights_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a signed-in admin" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "creates a highlight with a photo" do
      photo = fixture_file_upload("sample_product_image.jpg", "image/jpeg")

      expect {
        post admin_customer_highlights_path, params: {
          customer_highlight: {
            customer_name: "Ahmed R.", quote: "Great bike!", rating: 5, position: 0, active: true, photo: photo
          }
        }
      }.to change(CustomerHighlight, :count).by(1)

      highlight = CustomerHighlight.last
      expect(highlight.customer_name).to eq("Ahmed R.")
      expect(highlight.photo).to be_attached
      expect(response).to redirect_to(admin_customer_highlights_path)
    end

    it "creates a highlight with no photo — a text-only Google review works too" do
      expect {
        post admin_customer_highlights_path, params: {
          customer_highlight: { customer_name: "Sara K.", quote: "Fast delivery, great service.", rating: 4, position: 0, active: true }
        }
      }.to change(CustomerHighlight, :count).by(1)

      expect(CustomerHighlight.last.photo).not_to be_attached
    end

    it "rejects a rating outside 1..5, showing a real error" do
      expect {
        post admin_customer_highlights_path, params: {
          customer_highlight: { customer_name: "Ahmed R.", quote: "Great bike!", rating: 9, position: 0 }
        }
      }.not_to change(CustomerHighlight, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "updates a highlight's text and replaces its photo" do
      highlight = create(:customer_highlight, customer_name: "Old Name")
      new_photo = fixture_file_upload("sample_product_image.jpg", "image/jpeg")

      patch admin_customer_highlight_path(highlight), params: {
        customer_highlight: { customer_name: "New Name", photo: new_photo }
      }

      highlight.reload
      expect(highlight.customer_name).to eq("New Name")
      expect(highlight.photo).to be_attached
    end

    it "hides a highlight from the home page by toggling active off, without deleting it" do
      highlight = create(:customer_highlight, active: true)

      patch admin_customer_highlight_path(highlight), params: { customer_highlight: { active: false } }

      expect(highlight.reload.active?).to be false
    end

    it "deletes a highlight" do
      highlight = create(:customer_highlight)

      expect { delete admin_customer_highlight_path(highlight) }.to change(CustomerHighlight, :count).by(-1)
      expect(response).to redirect_to(admin_customer_highlights_path)
    end
  end
end
