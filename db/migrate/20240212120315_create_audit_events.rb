# frozen_string_literal: true

class CreateAuditEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_events do |t|
      t.timestamp :timestamp, null: false
      t.references :user, foreign_key: true, null: false
      t.integer :action, null: false
      t.integer :target_table, null: false
      t.text :target_object_id, null: false
    end
  end
end
