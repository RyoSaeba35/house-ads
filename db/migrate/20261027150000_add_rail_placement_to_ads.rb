# Adds a 4th placement, "rail": tall 1:2 ads for the side columns of websites on laptop/desktop.
class AddRailPlacementToAds < ActiveRecord::Migration[8.0]
  def change
    add_column :ads, :rail_enabled, :boolean, null: false, default: false
  end
end
