// backend/src/controllers/enterprise.controller.js
const db = require('../config/db');

// Helper to ensure store exists for user and return store_id
async function getOrCreateStore(firebaseUid, email = null) {
  let { rows } = await db.query(
    'SELECT * FROM enterprise_stores WHERE firebase_uid = $1',
    [firebaseUid]
  );
  if (rows.length === 0) {
    const insertRes = await db.query(
      `INSERT INTO enterprise_stores (firebase_uid, email, restaurant_name)
       VALUES ($1, $2, 'Naya restaurant')
       RETURNING *`,
      [firebaseUid, email]
    );
    return insertRes.rows[0];
  }
  return rows[0];
}

// ── STORE PROFILE & SETTINGS ─────────────────────────────
exports.getProfile = async (req, res) => {
  try {
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    return res.json({ profile: store });
  } catch (error) {
    console.error('getProfile error:', error);
    return res.status(500).json({ error: 'Failed to fetch store profile' });
  }
};

exports.saveProfile = async (req, res) => {
  try {
    const {
      owner_name,
      restaurant_name,
      mobile_number,
      city,
      state,
      upi_id,
      gst_percent,
      tables_count,
      bill_prefix,
      theme,
      notifications_enabled,
      enabled_modules,
    } = req.body;

    const email = req.user.email || req.body.email || '';

    const { rows } = await db.query(
      `INSERT INTO enterprise_stores (
        firebase_uid, owner_name, restaurant_name, mobile_number, email,
        city, state, upi_id, gst_percent, tables_count, bill_prefix,
        theme, notifications_enabled, enabled_modules, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, NOW())
      ON CONFLICT (firebase_uid) DO UPDATE SET
        owner_name = EXCLUDED.owner_name,
        restaurant_name = COALESCE(EXCLUDED.restaurant_name, enterprise_stores.restaurant_name),
        mobile_number = EXCLUDED.mobile_number,
        email = COALESCE(EXCLUDED.email, enterprise_stores.email),
        city = EXCLUDED.city,
        state = EXCLUDED.state,
        upi_id = EXCLUDED.upi_id,
        gst_percent = COALESCE(EXCLUDED.gst_percent, enterprise_stores.gst_percent),
        tables_count = COALESCE(EXCLUDED.tables_count, enterprise_stores.tables_count),
        bill_prefix = COALESCE(EXCLUDED.bill_prefix, enterprise_stores.bill_prefix),
        theme = COALESCE(EXCLUDED.theme, enterprise_stores.theme),
        notifications_enabled = COALESCE(EXCLUDED.notifications_enabled, enterprise_stores.notifications_enabled),
        enabled_modules = COALESCE(EXCLUDED.enabled_modules, enterprise_stores.enabled_modules),
        updated_at = NOW()
      RETURNING *`,
      [
        req.user.uid,
        owner_name || '',
        restaurant_name || 'Naya restaurant',
        mobile_number || '',
        email,
        city || '',
        state || '',
        upi_id || '',
        gst_percent ?? 5,
        tables_count ?? 8,
        bill_prefix || 'POS',
        theme || 'Auto',
        notifications_enabled ?? true,
        JSON.stringify(enabled_modules || {
          inventory: true,
          udhaar: true,
          staff: true,
          redeem: true,
          reports: true,
        }),
      ]
    );

    return res.json({ profile: rows[0], message: 'Settings saved successfully' });
  } catch (error) {
    console.error('saveProfile error:', error);
    return res.status(500).json({ error: 'Failed to save store profile' });
  }
};

// ── FOOD ITEMS & MENU ────────────────────────────────────
exports.getFoodItems = async (req, res) => {
  try {
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { rows } = await db.query(
      `SELECT * FROM enterprise_food_items
       WHERE store_id = $1 AND is_active = true
       ORDER BY category ASC, name ASC`,
      [store.id]
    );
    return res.json({ items: rows });
  } catch (error) {
    console.error('getFoodItems error:', error);
    return res.status(500).json({ error: 'Failed to fetch food items' });
  }
};

exports.addFoodItem = async (req, res) => {
  try {
    const { name, category, price } = req.body;
    if (!name || price == null) {
      return res.status(400).json({ error: 'Name and price are required' });
    }
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { rows } = await db.query(
      `INSERT INTO enterprise_food_items (store_id, name, category, price)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [store.id, name.trim(), (category || 'Main').trim(), Number(price)]
    );
    return res.status(201).json({ item: rows[0] });
  } catch (error) {
    console.error('addFoodItem error:', error);
    return res.status(500).json({ error: 'Failed to add food item' });
  }
};

exports.bulkImportFoodItems = async (req, res) => {
  try {
    const { items } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'Items list is required' });
    }
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const inserted = [];
    for (const item of items) {
      if (!item.name) continue;
      const { rows } = await db.query(
        `INSERT INTO enterprise_food_items (store_id, name, category, price)
         VALUES ($1, $2, $3, $4)
         RETURNING *`,
        [store.id, item.name.trim(), (item.category || 'Main').trim(), Number(item.price || 0)]
      );
      if (rows[0]) inserted.push(rows[0]);
    }
    return res.status(201).json({ count: inserted.length, items: inserted });
  } catch (error) {
    console.error('bulkImportFoodItems error:', error);
    return res.status(500).json({ error: 'Failed to bulk import food items' });
  }
};

exports.updateFoodItem = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, category, price, is_active } = req.body;
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { rows } = await db.query(
      `UPDATE enterprise_food_items
       SET name = COALESCE($1, name),
           category = COALESCE($2, category),
           price = COALESCE($3, price),
           is_active = COALESCE($4, is_active),
           updated_at = NOW()
       WHERE id = $5 AND store_id = $6
       RETURNING *`,
      [name, category, price != null ? Number(price) : null, is_active, id, store.id]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Item not found' });
    return res.json({ item: rows[0] });
  } catch (error) {
    console.error('updateFoodItem error:', error);
    return res.status(500).json({ error: 'Failed to update food item' });
  }
};

exports.deleteFoodItem = async (req, res) => {
  try {
    const { id } = req.params;
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    await db.query(
      'DELETE FROM enterprise_food_items WHERE id = $1 AND store_id = $2',
      [id, store.id]
    );
    return res.json({ success: true, id });
  } catch (error) {
    console.error('deleteFoodItem error:', error);
    return res.status(500).json({ error: 'Failed to delete food item' });
  }
};

// ── BILLING & BILLS ──────────────────────────────────────
exports.getBills = async (req, res) => {
  try {
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const limit = Math.min(Number(req.query.limit) || 100, 200);
    const { rows } = await db.query(
      `SELECT * FROM enterprise_bills
       WHERE store_id = $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [store.id, limit]
    );
    return res.json({ bills: rows });
  } catch (error) {
    console.error('getBills error:', error);
    return res.status(500).json({ error: 'Failed to fetch bills' });
  }
};

exports.createBill = async (req, res) => {
  try {
    const {
      bill_number,
      table_number,
      items,
      subtotal,
      gst_percent,
      gst_amount,
      total_amount,
      payment_mode,
    } = req.body;

    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const finalBillNumber = bill_number || `${store.bill_prefix || 'POS'}-${Date.now().toString().slice(-6)}`;

    const { rows } = await db.query(
      `INSERT INTO enterprise_bills (
        store_id, bill_number, table_number, items,
        subtotal, gst_percent, gst_amount, total_amount, payment_mode
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *`,
      [
        store.id,
        finalBillNumber,
        table_number || 'Table 1',
        JSON.stringify(items || []),
        Number(subtotal || 0),
        Number(gst_percent || 0),
        Number(gst_amount || 0),
        Number(total_amount || 0),
        payment_mode || 'Cash',
      ]
    );
    return res.status(201).json({ bill: rows[0] });
  } catch (error) {
    console.error('createBill error:', error);
    return res.status(500).json({ error: 'Failed to create bill' });
  }
};

// ── INVENTORY ────────────────────────────────────────────
exports.getInventory = async (req, res) => {
  try {
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { rows } = await db.query(
      `SELECT * FROM enterprise_inventory
       WHERE store_id = $1
       ORDER BY created_at DESC`,
      [store.id]
    );
    return res.json({ inventory: rows });
  } catch (error) {
    console.error('getInventory error:', error);
    return res.status(500).json({ error: 'Failed to fetch inventory' });
  }
};

exports.addInventory = async (req, res) => {
  try {
    const { item_name, quantity, amount, vendor, purchase_date } = req.body;
    if (!item_name) return res.status(400).json({ error: 'Item name is required' });
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { rows } = await db.query(
      `INSERT INTO enterprise_inventory (store_id, item_name, quantity, amount, vendor, purchase_date)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        store.id,
        item_name.trim(),
        Number(quantity || 1),
        Number(amount || 0),
        vendor || '',
        purchase_date || new Date().toISOString().split('T')[0],
      ]
    );
    return res.status(201).json({ inventory: rows[0] });
  } catch (error) {
    console.error('addInventory error:', error);
    return res.status(500).json({ error: 'Failed to add inventory' });
  }
};

exports.deleteInventory = async (req, res) => {
  try {
    const { id } = req.params;
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    await db.query('DELETE FROM enterprise_inventory WHERE id = $1 AND store_id = $2', [id, store.id]);
    return res.json({ success: true, id });
  } catch (error) {
    console.error('deleteInventory error:', error);
    return res.status(500).json({ error: 'Failed to delete inventory' });
  }
};

// ── CRM / UDHAAR ─────────────────────────────────────────
exports.getUdhaar = async (req, res) => {
  try {
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { rows } = await db.query(
      `SELECT * FROM enterprise_udhaar
       WHERE store_id = $1
       ORDER BY transaction_date DESC, created_at DESC`,
      [store.id]
    );
    return res.json({ udhaar: rows });
  } catch (error) {
    console.error('getUdhaar error:', error);
    return res.status(500).json({ error: 'Failed to fetch udhaar' });
  }
};

exports.addUdhaar = async (req, res) => {
  try {
    const { customer_name, amount, type, transaction_date, notes } = req.body;
    if (!customer_name || amount == null || !type) {
      return res.status(400).json({ error: 'Customer name, amount, and type (given/repaid) are required' });
    }
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { rows } = await db.query(
      `INSERT INTO enterprise_udhaar (store_id, customer_name, amount, type, transaction_date, notes)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        store.id,
        customer_name.trim(),
        Number(amount),
        type,
        transaction_date || new Date().toISOString().split('T')[0],
        notes || '',
      ]
    );
    return res.status(201).json({ record: rows[0] });
  } catch (error) {
    console.error('addUdhaar error:', error);
    return res.status(500).json({ error: 'Failed to add udhaar record' });
  }
};

// ── STAFF & ADVANCES ─────────────────────────────────────
exports.getStaff = async (req, res) => {
  try {
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { rows: staffRows } = await db.query(
      `SELECT * FROM enterprise_staff
       WHERE store_id = $1
       ORDER BY name ASC`,
      [store.id]
    );
    const { rows: advanceRows } = await db.query(
      `SELECT * FROM enterprise_staff_advances
       WHERE store_id = $1
       ORDER BY advance_date DESC`,
      [store.id]
    );

    const staffWithAdvances = staffRows.map((s) => ({
      ...s,
      advances: advanceRows.filter((a) => a.staff_id === s.id),
    }));

    return res.json({ staff: staffWithAdvances });
  } catch (error) {
    console.error('getStaff error:', error);
    return res.status(500).json({ error: 'Failed to fetch staff' });
  }
};

exports.addStaff = async (req, res) => {
  try {
    const { name, post, salary, joining_date } = req.body;
    if (!name || !post) {
      return res.status(400).json({ error: 'Name and post are required' });
    }
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { rows } = await db.query(
      `INSERT INTO enterprise_staff (store_id, name, post, salary, joining_date)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        store.id,
        name.trim(),
        post.trim(),
        Number(salary || 0),
        joining_date || new Date().toISOString().split('T')[0],
      ]
    );
    return res.status(201).json({ staff: { ...rows[0], advances: [] } });
  } catch (error) {
    console.error('addStaff error:', error);
    return res.status(500).json({ error: 'Failed to add staff' });
  }
};

exports.deleteStaff = async (req, res) => {
  try {
    const { id } = req.params;
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    await db.query('DELETE FROM enterprise_staff WHERE id = $1 AND store_id = $2', [id, store.id]);
    return res.json({ success: true, id });
  } catch (error) {
    console.error('deleteStaff error:', error);
    return res.status(500).json({ error: 'Failed to delete staff' });
  }
};

exports.addStaffAdvance = async (req, res) => {
  try {
    const { staff_id, amount, advance_date, notes } = req.body;
    if (!staff_id || amount == null) {
      return res.status(400).json({ error: 'staff_id and amount are required' });
    }
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { rows } = await db.query(
      `INSERT INTO enterprise_staff_advances (staff_id, store_id, amount, advance_date, notes)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        staff_id,
        store.id,
        Number(amount),
        advance_date || new Date().toISOString().split('T')[0],
        notes || '',
      ]
    );
    return res.status(201).json({ advance: rows[0] });
  } catch (error) {
    console.error('addStaffAdvance error:', error);
    return res.status(500).json({ error: 'Failed to record staff advance' });
  }
};

// ── REDEEM DEAL ──────────────────────────────────────────
exports.redeemDeal = async (req, res) => {
  try {
    const { deal_id, deal_code } = req.body;
    if (!deal_id || !deal_code) {
      return res.status(400).json({ error: 'deal_id and deal_code are required' });
    }
    const cleanCode = deal_code.trim().toUpperCase();

    // Find student with this deal code
    const userRes = await db.query(
      'SELECT id, name, email FROM users WHERE UPPER(deal_code) = $1',
      [cleanCode]
    );
    if (userRes.rows.length === 0) {
      return res.status(404).json({ error: 'Invalid deal code or student not found' });
    }
    const student = userRes.rows[0];

    // Check if already redeemed
    const checkRedeem = await db.query(
      'SELECT id FROM deal_redemptions WHERE deal_id = $1 AND user_id = $2',
      [deal_id, student.id]
    );
    if (checkRedeem.rows.length > 0) {
      return res.status(409).json({ error: 'Deal already redeemed by this student' });
    }

    const redeemRes = await db.query(
      `INSERT INTO deal_redemptions (deal_id, user_id, redeemed_at)
       VALUES ($1, $2, NOW())
       RETURNING *`,
      [deal_id, student.id]
    );

    return res.json({
      success: true,
      message: 'Offer redeemed successfully!',
      student: { name: student.name, email: student.email },
      redeemed_at: redeemRes.rows[0].redeemed_at,
    });
  } catch (error) {
    console.error('redeemDeal error:', error);
    return res.status(500).json({ error: 'Failed to redeem offer' });
  }
};

// ── DELTA SYNC ENGINE (OFFLINE-FIRST) ────────────────────
exports.syncDelta = async (req, res) => {
  try {
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { mutations } = req.body;

    if (Array.isArray(mutations)) {
      for (const m of mutations) {
        if (!m || !m.type) continue;
        switch (m.type) {
          case 'create_bill':
            if (m.payload) {
              await db.query(
                `INSERT INTO enterprise_bills (
                  store_id, bill_number, table_number, items,
                  subtotal, gst_percent, gst_amount, total_amount, payment_mode, created_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, COALESCE($10, NOW()))
                ON CONFLICT (id) DO NOTHING`,
                [
                  store.id,
                  m.payload.bill_number,
                  m.payload.table_number || 'Table 1',
                  JSON.stringify(m.payload.items || []),
                  Number(m.payload.subtotal || 0),
                  Number(m.payload.gst_percent || 0),
                  Number(m.payload.gst_amount || 0),
                  Number(m.payload.total_amount || 0),
                  m.payload.payment_mode || 'Cash',
                  m.payload.created_at || null,
                ]
              );
            }
            break;
          case 'add_udhaar':
            if (m.payload) {
              await db.query(
                `INSERT INTO enterprise_udhaar (store_id, customer_name, amount, type, transaction_date, notes)
                 VALUES ($1, $2, $3, $4, $5, $6)`,
                [
                  store.id,
                  m.payload.customer_name,
                  Number(m.payload.amount || 0),
                  m.payload.type,
                  m.payload.transaction_date || new Date().toISOString().split('T')[0],
                  m.payload.notes || '',
                ]
              );
            }
            break;
          case 'add_inventory':
            if (m.payload) {
              await db.query(
                `INSERT INTO enterprise_inventory (store_id, item_name, quantity, amount, vendor, purchase_date)
                 VALUES ($1, $2, $3, $4, $5, $6)`,
                [
                  store.id,
                  m.payload.item_name,
                  Number(m.payload.quantity || 1),
                  Number(m.payload.amount || 0),
                  m.payload.vendor || '',
                  m.payload.purchase_date || new Date().toISOString().split('T')[0],
                ]
              );
            }
            break;
          default:
            break;
        }
      }
    }

    // Return current consolidated state
    const [foodItems, bills, inventory, udhaar, staff] = await Promise.all([
      db.query('SELECT * FROM enterprise_food_items WHERE store_id = $1 AND is_active = true', [store.id]),
      db.query('SELECT * FROM enterprise_bills WHERE store_id = $1 ORDER BY created_at DESC LIMIT 100', [store.id]),
      db.query('SELECT * FROM enterprise_inventory WHERE store_id = $1 ORDER BY created_at DESC', [store.id]),
      db.query('SELECT * FROM enterprise_udhaar WHERE store_id = $1 ORDER BY transaction_date DESC', [store.id]),
      db.query('SELECT * FROM enterprise_staff WHERE store_id = $1', [store.id]),
    ]);

    return res.json({
      synced_at: new Date().toISOString(),
      store,
      food_items: foodItems.rows,
      bills: bills.rows,
      inventory: inventory.rows,
      udhaar: udhaar.rows,
      staff: staff.rows,
    });
  } catch (error) {
    console.error('syncDelta error:', error);
    return res.status(500).json({ error: 'Failed to synchronize delta' });
  }
};
