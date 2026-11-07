Bridge = Bridge or {}
Bridge.Inventory = Bridge.Inventory or {}

-- wu-reticle ではインベントリ操作を使用しないため軽量スタブとして保持（ファイル構成互換用）
function Bridge.Inventory.AddItem() return false end
function Bridge.Inventory.RemoveItem() return false end
function Bridge.Inventory.GetItemCount() return 0 end
function Bridge.Inventory.HasItem() return false end
