class Ad < ApplicationRecord
  PLACEMENTS = %w[banner square interstitial rail].freeze
  IMAGE_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  MAX_IMAGE_SIZE = 2.megabytes
  DEFAULT_ASPECT = { "banner" => 6.0, "square" => 1.0, "interstitial" => 0.5625, "rail" => 0.5 }.freeze
  SUGGESTED_SIZE = { "banner" => "1200×200", "square" => "1080×1080", "interstitial" => "1080×1920", "rail" => "600×1200" }.freeze

  PLACEMENTS.each { |placement| has_one_attached :"#{placement}_image" }
  has_many :daily_stats, class_name: "AdDailyStat", inverse_of: :ad

  before_validation :normalize_fields

  validates :name, presence: true, length: { maximum: 120 }
  validates :target_url, presence: true,
                         format: { with: %r{\Ahttps?://\S+\z}i, message: "must start with http:// or https://" }
  validates :weight, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :label, presence: true, length: { maximum: 30 }
  validate :at_least_one_placement
  validate :images_must_be_valid
  validate :schedule_must_be_coherent

  scope :with_all_images, -> { PLACEMENTS.inject(all) { |rel, p| rel.public_send(:"with_attached_#{p}_image") } }
  scope :live, lambda {
    now = Time.current
    where(active: true)
      .where("starts_at IS NULL OR starts_at <= ?", now)
      .where("ends_at IS NULL OR ends_at > ?", now)
  }
  scope :for_placement, ->(placement) { PLACEMENTS.include?(placement) ? where("#{placement}_enabled": true) : none }
  scope :for_app, lambda { |key|
    where("cardinality(app_keys) = 0 OR ? = ANY(app_keys)", key)
      .where("target_app_key IS NULL OR target_app_key <> ?", key)
  }

  def self.valid_placement(value)
    PLACEMENTS.include?(value.to_s) ? value.to_s : nil
  end

  def image_for(placement)
    public_send(:"#{placement}_image")
  end

  def enabled?(placement)
    public_send(:"#{placement}_enabled")
  end

  # Ticked AND has an image: the API will return this ad for that placement.
  def serves?(placement)
    enabled?(placement) && image_for(placement).attached?
  end

  def placements
    PLACEMENTS.select { |placement| enabled?(placement) }
  end

  def preview_image
    candidates = placements + PLACEMENTS
    candidates.map { |placement| image_for(placement) }.find(&:attached?)
  end

  def aspect_ratio(placement)
    image = image_for(placement)
    meta = image.attached? ? image.blob.metadata : {}
    width = meta["width"].to_f
    height = meta["height"].to_f
    width.positive? && height.positive? ? (width / height).round(4) : DEFAULT_ASPECT.fetch(placement)
  end

  def live?
    now = Time.current
    active? && (starts_at.nil? || starts_at <= now) && (ends_at.nil? || ends_at > now)
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

  def at_least_one_placement
    errors.add(:base, "Tick at least one placement") if placements.empty?
  end

  def images_must_be_valid
    PLACEMENTS.each do |placement|
      image = image_for(placement)
      label = placement.capitalize

      if enabled?(placement) && !image.attached?
        errors.add(:base, "#{label} image is required when #{label} is ticked")
      end
      next unless image.attached?

      errors.add(:base, "#{label} image must be PNG, JPEG, WebP or GIF") unless image.blob.content_type.in?(IMAGE_TYPES)
      errors.add(:base, "#{label} image must be under 2 MB") if image.blob.byte_size > MAX_IMAGE_SIZE
    end
  end

  def schedule_must_be_coherent
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start date") if ends_at <= starts_at
  end
end
