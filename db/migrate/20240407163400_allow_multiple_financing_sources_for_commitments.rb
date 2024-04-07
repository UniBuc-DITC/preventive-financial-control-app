# frozen_string_literal: true

class AllowMultipleFinancingSourcesForCommitments < ActiveRecord::Migration[7.1]
  def up
    # rubocop:disable Rails/CreateTableWithTimestamps
    create_table :commitment_financing_source_associations do |t|
      t.belongs_to :commitment, foreign_key: true
      t.belongs_to :financing_source, foreign_key: true
      t.index %i[commitment_id financing_source_id], unique: true
    end
    # rubocop:enable Rails/CreateTableWithTimestamps

    execute <<-SQL.squish
        INSERT INTO commitment_financing_source_associations (commitment_id, financing_source_id)
        SELECT id, financing_source_id
        FROM commitments;
    SQL

    change_table :commitments do |t|
      t.remove_foreign_key :financing_sources
      t.remove_index :financing_source_id
      t.remove :financing_source_id
    end
  end

  def down
    change_table :commitments do |t|
      t.integer :financing_source_id, null: true
      t.index :financing_source_id
      t.foreign_key :financing_sources
    end

    execute <<-SQL.squish
        UPDATE commitments
        SET financing_source_id = (
            SELECT financing_source_id
            FROM commitment_financing_source_associations
            WHERE commitment_id = commitments.id
        );
    SQL

    change_column_null :commitments, :financing_source_id, false

    drop_table :commitment_financing_source_associations
  end
end
