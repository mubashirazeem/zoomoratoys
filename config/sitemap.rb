# frozen_string_literal: true

SitemapGenerator::Sitemap.default_host = "https://zoomora.com"

SitemapGenerator::Sitemap.create do
  # root_path is added automatically by the gem — see the comment this file
  # was generated with. Adding it again here would duplicate that entry.
  add products_path, priority: 0.9, changefreq: "daily"
  add blog_posts_path, priority: 0.6, changefreq: "weekly"

  add about_path, priority: 0.4, changefreq: "monthly"
  add faq_path, priority: 0.3, changefreq: "monthly"
  add rentals_path, priority: 0.4, changefreq: "monthly"
  add contact_path, priority: 0.3, changefreq: "monthly"
  add privacy_policy_path, priority: 0.2, changefreq: "yearly"
  add terms_and_conditions_path, priority: 0.2, changefreq: "yearly"
  add shipping_and_returns_path, priority: 0.2, changefreq: "yearly"

  Product.find_each do |product|
    add product_path(product), lastmod: product.updated_at, priority: 0.8, changefreq: "weekly"
  end

  BlogPost.published.find_each do |blog_post|
    add blog_post_path(blog_post), lastmod: blog_post.updated_at, priority: 0.5, changefreq: "monthly"
  end
end
