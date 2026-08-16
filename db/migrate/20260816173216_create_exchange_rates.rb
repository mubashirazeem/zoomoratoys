class CreateExchangeRates < ActiveRecord::Migration[7.2]
  def change
    create_table :exchange_rates do |t|
      t.decimal :usd_per_aed, precision: 12, scale: 6, null: false
      t.datetime :fetched_at, null: false

      t.timestamps
    end
  end
end
