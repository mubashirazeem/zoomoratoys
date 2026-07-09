require "rails_helper"

RSpec.describe "ContactMessages", type: :request do
  describe "GET /contact" do
    it "succeeds" do
      get contact_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /contact" do
    it "creates a contact message and redirects with a confirmation" do
      expect {
        post contact_path, params: { contact_message: attributes_for(:contact_message) }
      }.to change(ContactMessage, :count).by(1)

      expect(response).to redirect_to(contact_path)
      follow_redirect!
      expect(response.body).to include("Thanks for reaching out")
    end

    it "re-renders the form with errors when invalid" do
      expect {
        post contact_path, params: { contact_message: { name: "", email: "not-an-email", subject: "", message: "" } }
      }.not_to change(ContactMessage, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Please fix the following")
    end
  end
end
