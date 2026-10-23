class CreateAdDailyStats < ActiveRecord::Migration[8.0]
  def change
    create_table :ad_daily_stats do |t|
      t.references :ad, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :day, null: false
      t.string :app_key, null: false, default: "unknown"
      t.integer :impressions, null: false, default: 0
      t.integer :clicks, null: false, default: 0
      t.timestamps
    end

    add_index :ad_daily_stats, [:ad_id, :day, :app_key], unique: true
    add_index :ad_daily_stats, :day
  end
end
