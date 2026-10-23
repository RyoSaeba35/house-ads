class Ad < ApplicationRecord
  PLACEMENTS = %w[banner square interstitial].freeze
  IMAGE_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  MAX_IMAGE_SIZE = 2.megabytes
  DEFAULT_ASPECT = { "banner" => 6.0, "square" => 1.0, "interstitial" => 0.5625 }.freeze

  has_one_attached :image
  has_many :daily_stats, class_name: "AdDailyStat", inverse_of: :ad

  before_validation :normalize_fields

  validates :name, presence: true, length: { maximum: 120 }
  validates :target_url, presence: true,
                         format: { with: %r{\Ahttps?://\S+\z}i, message: "must start with http:// or https://" }
  validates :placement, inclusion: { in: PLACEMENTS }
  validates :weight, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :label, presence: true, length: { maximum: 30 }
  validate :image_must_be_valid
  validate :schedule_must_be_coherent

  scope :live, lambda {
    now = Time.current
    where(active: true)
      .where("starts_at IS NULL OR starts_at <= ?", now)
      .where("ends_at IS NULL OR ends_at > ?", now)
  }
  scope :for_placement, ->(placement) { placement.present? ? where(placement: placement) : all }
  scope :for_app, lambda { |key|
    where("cardinality(app_keys) = 0 OR ? = ANY(app_keys)", key)
      .where("target_app_key IS NULL OR target_app_key <> ?", key)
  }

  def live?
    now = Time.current
    active? && (starts_at.nil? || starts_at <= now) && (ends_at.nil? || ends_at > now)
  end

  def aspect_ratio
    meta = image.attached? ? image.blob.metadata : {}
    width = meta["width"].to_f
    height = meta["height"].to_f
    width.positive? && height.positive? ? (width / height).round(4) : DEFAULT_ASPECT.fetch(placement, 6.0)
  end

  def app_keys_list
    app_keys.join(", ")
  end

  def app_keys_list=(value)
    self.app_keys = value.to_s.split(",")
                         .map { |key| AdDailyStat.normalize_app_key(key) }
                         .reject { |key| key == AdDailyStat::UNKNOWN_APP }
                         .uniq
  end

  private

  def normalize_fields
    self.name = name.to_s.strip
    self.target_url = target_url.to_s.strip
    self.label = label.to_s.strip.presence || "Publicité"
    key = AdDailyStat.normalize_app_key(target_app_key)
    self.target_app_key = key == AdDailyStat::UNKNOWN_APP ? nil : key
  end

  def image_must_be_valid
    unless image.attached?
      errors.add(:image, "is required")
      return
    end

    errors.add(:image, "must be PNG, JPEG, WebP or GIF") unless image.blob.content_type.in?(IMAGE_TYPES)
    errors.add(:image, "must be under 2 MB") if image.blob.byte_size > MAX_IMAGE_SIZE
  end

  def schedule_must_be_coherent
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start date") if ends_at <= starts_at
  end
end
