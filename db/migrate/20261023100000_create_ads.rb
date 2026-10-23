class CreateAds < ActiveRecord::Migration[8.0]
  def change
    create_table :ads do |t|
      t.string :name, null: false
      t.string :target_url, null: false
      t.string :placement, null: false, default: "banner"
      t.integer :weight, null: false, default: 10
      t.boolean :active, null: false, default: true
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :app_keys, array: true, null: false, default: []
      t.string :target_app_key
      t.string :label, null: false, default: "Publicité"
      t.string :alt_text
      t.timestamps
    end

    add_index :ads, [:placement, :active]
  end
end
