# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ui::PaginationComponent, type: :component do
  it "renders nothing when everything fits on one page" do
    create_list(:product, 2)
    scope = Product.page(1).per(10)

    render_inline(described_class.new(scope: scope) { |page| "/shop?page=#{page}" })

    expect(page).not_to have_css("nav")
  end

  it "renders page links and highlights the current page when there's more than one page" do
    create_list(:product, 5)
    scope = Product.page(2).per(2)

    render_inline(described_class.new(scope: scope) { |page| "/shop?page=#{page}" })

    expect(page).to have_css("nav[aria-label='Pagination']")
    expect(page).to have_link("1", href: "/shop?page=1")
    expect(page).to have_link("3", href: "/shop?page=3")
    expect(page).to have_css("[aria-current='page']", text: "2")
  end
end
