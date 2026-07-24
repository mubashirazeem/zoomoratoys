class AddSafetyAndCareNotesToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :safety_notes, :text
    add_column :products, :care_notes, :text
  end
end
