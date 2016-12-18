class CreateJournals < ActiveRecord::Migration
  def change
    create_table :journals do |t|
      t.integer :journalized_id, null: false
      t.string :journalized_type, null: false
      t.references :user, null: false, index: true
      t.timestamps null: false
    end

    add_index :journals, [:journalized_id, :journalized_type], :name => "journals_journalized_id"

    create_table :journal_details do |t|
      d = {default: '', null: false}
      t.references :journal, null: false, index: true
      t.string  :property, d
      t.text :value, d
      t.text :old_value, d
      t.integer :approve_state, null: false, default: Approvable::Model::STATES[:not_marked]
      t.text :approve_refused_cause
    end
  end
end
