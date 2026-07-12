# frozen_string_literal: true

require "rails_helper"

RSpec.describe Layout::SiteHeaderComponent, type: :component do
  it "renders the logo image, linking home, with an accessible name" do
    render_inline(described_class.new)

    expect(page).to have_css("a[href='/'] img[alt='Zoomora — Adventure Starts Here']")
  end

  it "renders Home, About, and Contact around the category links" do
    render_inline(described_class.new)

    expect(page).to have_link("Home", href: "/")
    expect(page).to have_link("About", href: "/about")
    expect(page).to have_link("Contact", href: "/contact")
  end

  it "renders the category's own name as the nav label and shop link" do
    # The label comes directly from Category#name (not a placeholder_key
    # lookup) — several categories intentionally share a placeholder_key/
    # photo (e.g. Scooters and Cargo Scooters both use "scooter"), so a
    # keyed lookup can't tell two same-keyed categories' labels apart.
    scooters = build_stubbed(:category, name: "Scooters", slug: "electric-scooters", placeholder_key: "scooter")
    golf = build_stubbed(:category, name: "Golf Carts", slug: "golf-carts", placeholder_key: "golf_cart")

    render_inline(described_class.new(categories: [ scooters, golf ]))

    expect(page).to have_link("Scooters", href: "/shop?category=electric-scooters")
    expect(page).to have_link("Golf Carts", href: "/shop?category=golf-carts")
  end

  it "renders a store search form pointing at the shop page" do
    render_inline(described_class.new)

    expect(page).to have_css("form[action='/shop'][method='get'] input[name='q']")
  end

  it "renders a labeled mobile menu trigger" do
    render_inline(described_class.new)

    expect(page).to have_css("button[aria-label='Open menu']")
  end

  it "prompts a signed-out visitor to sign in" do
    render_inline(described_class.new(current_user: nil))

    expect(page).to have_link("Sign In", href: "/users/sign_in")
    expect(page).not_to have_text("My Account")
  end

  it "greets a signed-in user by first name and offers the account dashboard + sign out" do
    user = build_stubbed(:user, first_name: "Layla")

    render_inline(described_class.new(current_user: user))

    expect(page).to have_text("Hi, Layla")
    expect(page).to have_link("My Account", href: "/account")
    expect(page).to have_link("Sign Out", href: "/users/sign_out")
  end

  it "shows the cart and wishlist item counts passed in" do
    render_inline(described_class.new(cart_item_count: 2, wishlist_item_count: 3))

    expect(page).to have_css("[aria-label*='Open cart, 2 items']")
    expect(page.find_link(href: "/wishlist").text).to include("3")
  end
end
