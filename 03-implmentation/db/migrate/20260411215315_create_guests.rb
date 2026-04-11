class CreateGuests < ActiveRecord::Migration[7.2]
  def change
    create_table :guests do |t|
      t.string :xen_name

      t.timestamps
    end
    add_index :guests, :xen_name, unique: true
  end
end
