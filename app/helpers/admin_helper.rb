module AdminHelper
  def ctr(impressions, clicks)
    return "-" if impressions.to_i.zero?

    format("%.2f%%", clicks.to_f * 100 / impressions)
  end

  def num(value)
    number_with_delimiter(value.to_i, delimiter: " ")
  end

  def ad_status(ad)
    return %w[paused muted] unless ad.active?
    return %w[scheduled info] if ad.starts_at&.future?
    return %w[ended muted] if ad.ends_at && ad.ends_at <= Time.current

    %w[live ok]
  end

  def status_badge(ad)
    label, kind = ad_status(ad)
    tag.span(label, class: "badge #{kind}")
  end

  def ad_thumb(ad, css = "thumb", placement: nil)
    image = ad && (placement ? ad.image_for(placement) : ad.preview_image)
    return tag.div(class: "#{css} empty-thumb") unless image&.attached?

    image_tag url_for(image), class: css, alt: ad.alt_text.presence || ad.name, loading: "lazy"
  end

  def placement_badges(ad)
    safe_join(Ad::PLACEMENTS.map do |placement|
      if ad.serves?(placement)
        tag.span(placement, class: "badge ok")
      elsif ad.image_for(placement).attached?
        tag.span(placement, class: "badge muted", title: "Image uploaded but not ticked")
      end
    end.compact, " ")
  end

  def period_links(current, path_builder)
    safe_join(%w[7 30 90].map do |period|
      link_to "#{period} days", path_builder.call(period), class: ["pill", ("active" if period == current)]
    end)
  end

  def fmt_time(time)
    time ? l(time, format: "%d/%m/%Y %H:%M") : "-"
  end
end
