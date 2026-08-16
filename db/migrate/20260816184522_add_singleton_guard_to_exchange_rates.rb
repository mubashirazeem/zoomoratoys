class AddSingletonGuardToExchangeRates < ActiveRecord::Migration[7.2]
  def change
    # Always the same value (1) on every row — the unique index below is
    # what actually stops two concurrent ExchangeRates::RefreshJob runs from
    # each inserting their own "first" row (see ExchangeRate.record!):
    # app-level first_or_initialize alone can't prevent that race, only a
    # real database constraint can. default: 1 backfills any existing row.
    add_column :exchange_rates, :singleton_guard, :integer, default: 1, null: false
    add_index :exchange_rates, :singleton_guard, unique: true
  end
end
