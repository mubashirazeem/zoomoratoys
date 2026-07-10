# frozen_string_literal: true

class BlogPost < ApplicationRecord
  # Reuses the same placeholder photo set as Category/Product
  # (category-<key>.jpg) so a post's cover art stays consistent with the
  # rest of the site instead of needing its own asset library.
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :excerpt, presence: true
  validates :body, presence: true
  validates :cover_image_key, presence: true, inclusion: { in: Category::PLACEHOLDER_KEYS }
  validates :published_at, presence: true

  before_validation :assign_slug, on: :create

  scope :newest_first, -> { order(published_at: :desc) }

  def to_param
    slug
  end

  private

  def assign_slug
    self.slug = title.to_s.parameterize if slug.blank? && title.present?
  end
end
