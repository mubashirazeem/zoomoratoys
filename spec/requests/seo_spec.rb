require "rails_helper"

RSpec.describe "SEO", type: :request do
  describe "Organization structured data" do
    it "renders sitewide Organization JSON-LD" do
      get root_path

      expect(response.body).to include('"@type":"Organization"')
      expect(response.body).to include('"name":"Zoomora"')
    end
  end

  describe "Open Graph and Twitter Card tags" do
    it "renders og/twitter tags using the page's own title and description" do
      get about_path

      expect(response.body).to include('<meta property="og:title" content="About Us | Zoomora">')
      expect(response.body).to include('<meta property="og:description" content="Zoomora is a family adventure store built around one idea: the best childhoods happen outside.">')
      expect(response.body).to include('<meta name="twitter:card" content="summary_large_image">')
      expect(response.body).to include('<meta name="twitter:title" content="About Us | Zoomora">')
    end

    it "falls back to the sitewide description on a page that doesn't set one" do
      get rentals_path

      expect(response.body).to include('<meta property="og:description" content="Zoomora — electric bikes, cargo scooters, ATVs, dirt bikes, and inflatables for family adventure.">')
    end
  end

  describe "canonical URL" do
    it "renders a self-referencing canonical link, dropping the query string" do
      get products_path(sort: "price_asc")

      expect(response.body).to include(%(<link rel="canonical" href="#{request.base_url}/shop">))
    end
  end

  describe "robots meta tag" do
    it "defaults to indexable on a public page" do
      get root_path

      expect(response.body).to include('<meta name="robots" content="index, follow">')
      expect(response.body).not_to match(/<meta name="robots" content="noindex/)
    end

    it "is noindex on a private customer page" do
      user = create(:user)
      sign_in user

      get account_path

      expect(response.body).to include('<meta name="robots" content="noindex, nofollow">')
    end

    it "is noindex on every admin page" do
      sign_in create(:admin_user), scope: :admin_user

      get admin_root_path

      expect(response.body).to include('<meta name="robots" content="noindex, nofollow">')
    end
  end
end
