# frozen_string_literal: true

class AddColorsToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      t.column :background_color, :string, null: false, default: '#FFFFFF'
      t.column :text_color, :string, null: false, default: '#000000'
    end
  end
end
