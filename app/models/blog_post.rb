# frozen_string_literal: true

class BlogPost < ApplicationRecord
  has_paper_trail

  # Real, admin-uploaded cover photo (optional) — falls back to the shared
  # category-style placeholder photo set (cover_image_key) for posts an
  # admin hasn't uploaded a real photo for yet, same two-tier pattern as
  # Product#images.
  has_one_attached :cover_image

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :excerpt, presence: true
  validates :body, presence: true
  validates :cover_image_key, presence: true, inclusion: { in: Category::PLACEHOLDER_KEYS }
  validates :published_at, presence: true

  before_validation :assign_slug, on: :create

  scope :newest_first, -> { order(published_at: :desc) }
  scope :published, -> { where(published_at: ..Time.current) }

  def to_param
    slug
  end

  def published?
    published_at.present? && published_at <= Time.current
  end

  private

  def assign_slug
    self.slug = title.to_s.parameterize if slug.blank? && title.present?
  end
end
