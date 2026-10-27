class AddExtractionProvenance < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :extraction_mode, :string, default: 'local_rules', null: false
    add_column :documents, :extraction_metadata, :jsonb, default: {}, null: false
    add_column :contract_fields, :uncertainty, :string
    add_column :workspaces, :demo_expires_at, :datetime
    add_index :workspaces, :demo_expires_at
    create_table :extraction_runs do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'running'
      t.string :model, null: false
      t.integer :revision, null: false
      t.jsonb :usage, null: false, default: {}
      t.string :error_code
      t.timestamps
    end
  end
end
