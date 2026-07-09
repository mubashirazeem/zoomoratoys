# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :category

  enum :stock_status, { in_stock: "in_stock", sold_out: "sold_out", preorder: "preorder" },
       default: "in_stock", validate: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :sku, presence: true, uniqueness: true
  validates :price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :placeholder_key, presence: true, inclusion: { in: Category::PLACEHOLDER_KEYS }

  before_validation :assign_slug, on: :create

  scope :ordered, -> { order(:position, :name) }
  scope :featured, -> { where(featured: true) }
  scope :best_sellers, -> { where(best_seller: true) }
  scope :newest_first, -> { order(created_at: :desc) }

  def to_param
    slug
  end

  private

  def assign_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
