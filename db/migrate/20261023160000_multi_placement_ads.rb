# One ad now holds up to 3 images (banner / square / interstitial), each with its own checkbox.
# Existing ads are converted: their single image becomes the image of their old placement.
class MultiPlacementAds < ActiveRecord::Migration[8.0]
  def up
    add_column :ads, :banner_enabled, :boolean, null: false, default: false
    add_column :ads, :square_enabled, :boolean, null: false, default: false
    add_column :ads, :interstitial_enabled, :boolean, null: false, default: false

    execute <<~SQL
      UPDATE ads SET
        banner_enabled = (placement = 'banner'),
        square_enabled = (placement = 'square'),
        interstitial_enabled = (placement = 'interstitial')
    SQL

    execute <<~SQL
      UPDATE active_storage_attachments att
      SET name = ads.placement || '_image'
      FROM ads
      WHERE att.record_type = 'Ad' AND att.record_id = ads.id AND att.name = 'image'
    SQL

    add_column :ad_daily_stats, :placement, :string, null: false, default: "banner"
    execute <<~SQL
      UPDATE ad_daily_stats s SET placement = ads.placement FROM ads WHERE s.ad_id = ads.id
    SQL

    remove_index :ad_daily_stats, column: [:ad_id, :day, :app_key]
    add_index :ad_daily_stats, [:ad_id, :day, :app_key, :placement],
              unique: true, name: "index_ad_daily_stats_uniqueness"

    remove_index :ads, column: [:placement, :active]
    remove_column :ads, :placement
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
