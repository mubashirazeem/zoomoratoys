# frozen_string_literal: true

class Category < ApplicationRecord
  # Visual "kind" for a category/product. Drives which placeholder photo
  # (category-<key>.jpg) and short nav/tile label are used, and is shared
  # with Product so a product stays visually consistent with its category.
  # See DESIGN_SYSTEM.md and Catalog::CategoryTileComponent::SHORT_LABELS.
  PLACEHOLDER_KEYS = %w[
    rideon scooter golf_cart bicycle atv trampoline pool playset
  ].freeze

  has_many :products, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :placeholder_key, presence: true, inclusion: { in: PLACEHOLDER_KEYS }

  before_validation :assign_slug, on: :create

  scope :ordered, -> { order(:position, :name) }

  def to_param
    slug
  end

  private

  def assign_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
