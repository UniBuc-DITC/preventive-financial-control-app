# frozen_string_literal: true

class ChangeSettingsValueFromJsonToJsonb < ActiveRecord::Migration[7.1]
  def up
    change_column :settings, :value, :jsonb
  end
end
