# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Currencies", type: :request do
  describe "POST /currency" do
    it "sets the currency cookie and redirects back to where the request came from" do
      post currency_path(code: "USD"), headers: { "HTTP_REFERER" => cart_url }

      expect(response).to redirect_to(cart_url)
      expect(cookies[:currency]).to eq("USD")
    end

    it "accepts switching back to AED" do
      post currency_path(code: "USD"), headers: { "HTTP_REFERER" => cart_url }
      post currency_path(code: "AED"), headers: { "HTTP_REFERER" => cart_url }

      expect(cookies[:currency]).to eq("AED")
    end

    it "ignores an unrecognized currency code instead of setting a bogus cookie" do
      post currency_path(code: "GBP"), headers: { "HTTP_REFERER" => root_url }

      expect(cookies[:currency]).to be_nil
    end

    it "falls back to the homepage when there's no referer to return to" do
      post currency_path(code: "USD")

      expect(response).to redirect_to(root_url)
    end

    it "does not blow up when no code param is given at all" do
      expect { post currency_path }.not_to raise_error

      expect(cookies[:currency]).to be_nil
    end

    it "is case-sensitive and rejects a lowercase 'usd'" do
      post currency_path(code: "usd")

      expect(cookies[:currency]).to be_nil
    end

    it "rejects an array/hash-shaped code param instead of erroring on a type mismatch" do
      expect { post currency_path, params: { code: [ "USD", "AED" ] } }.not_to raise_error

      expect(cookies[:currency]).to be_nil
    end
  end

  describe "GET /currency" do
    it "isn't a routable action — switching currency is POST-only, so a bare link/GET can't silently change it" do
      get currency_path(code: "USD")

      expect(response).to have_http_status(:not_found)
      expect(cookies[:currency]).to be_nil
    end
  end
end
