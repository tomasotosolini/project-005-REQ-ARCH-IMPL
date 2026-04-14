class AddPendingOperationToGuests < ActiveRecord::Migration[7.2]
  def change
    add_column :guests, :pending_operation, :string
  end
end
