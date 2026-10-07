// backend/src/controllers/enterprise.controller.js
const db = require('../config/db');

// Helper to ensure store exists for user and return store_id
async function getOrCreateStore(firebaseUid, email = null) {
  let { rows } = await db.query(
    'SELECT * FROM enterprise_stores WHERE firebase_uid = $1',
    [firebaseUid]
  );
  if (rows.length === 0) {
    // Ensure parent user record exists in users table to prevent FK violation
    await db.query(
      `INSERT INTO users (firebase_uid, email, name, is_enterprise)
       VALUES ($1, $2, 'Store Owner', true)
       ON CONFLICT (firebase_uid) DO UPDATE SET is_enterprise = true`,
      [firebaseUid, email || '']
    );
    const insertRes = await db.query(
      `INSERT INTO enterprise_stores (firebase_uid, email, restaurant_name)
       VALUES ($1, $2, 'Naya restaurant')
       ON CONFLICT (firebase_uid) DO UPDATE SET email = COALESCE(EXCLUDED.email, enterprise_stores.email)
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
    const { rows: staffCheck } = await db.query(
      'SELECT id FROM enterprise_staff WHERE id = $1 AND store_id = $2',
      [staff_id, store.id]
    );
    if (!staffCheck.length) {
      return res.status(404).json({ error: 'Staff member not found in your store' });
    }
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

// Helper to return complete consolidated state for store
async function buildConsolidatedResponse(store) {
  const [foodItems, bills, inventory, udhaar, staffRows, advanceRows] = await Promise.all([
    db.query(
      'SELECT * FROM enterprise_food_items WHERE store_id = $1 AND is_active = true ORDER BY category ASC, name ASC',
      [store.id]
    ),
    db.query(
      'SELECT * FROM enterprise_bills WHERE store_id = $1 ORDER BY created_at DESC LIMIT 150',
      [store.id]
    ),
    db.query(
      'SELECT * FROM enterprise_inventory WHERE store_id = $1 ORDER BY created_at DESC',
      [store.id]
    ),
    db.query(
      'SELECT * FROM enterprise_udhaar WHERE store_id = $1 ORDER BY transaction_date DESC, created_at DESC',
      [store.id]
    ),
    db.query(
      'SELECT * FROM enterprise_staff WHERE store_id = $1 ORDER BY name ASC',
      [store.id]
    ),
    db.query(
      'SELECT * FROM enterprise_staff_advances WHERE store_id = $1 ORDER BY advance_date DESC',
      [store.id]
    ),
  ]);

  const staffWithAdvances = staffRows.rows.map((s) => ({
    ...s,
    advances: advanceRows.rows.filter((a) => a.staff_id === s.id),
  }));

  return {
    synced_at: new Date().toISOString(),
    store,
    food_items: foodItems.rows,
    bills: bills.rows,
    inventory: inventory.rows,
    udhaar: udhaar.rows,
    staff: staffWithAdvances,
  };
}

// ── CONSOLIDATED STORE STATE FETCH ───────────────────────
exports.getConsolidated = async (req, res) => {
  try {
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const consolidated = await buildConsolidatedResponse(store);
    return res.json(consolidated);
  } catch (error) {
    console.error('getConsolidated error:', error);
    return res.status(500).json({ error: 'Failed to fetch consolidated store data' });
  }
};

// ── DELTA SYNC ENGINE (OFFLINE-FIRST) ────────────────────
exports.syncDelta = async (req, res) => {
  try {
    const store = await getOrCreateStore(req.user.uid, req.user.email);
    const { mutations } = req.body;

    if (Array.isArray(mutations)) {
      for (const m of mutations) {
        if (!m || !m.type || !m.payload) continue;
        const p = m.payload;

        try {
          switch (m.type) {
            case 'create_bill': {
              const finalBillNumber = p.bill_number || p.billNumber || `${store.bill_prefix || 'POS'}-${Date.now().toString().slice(-6)}`;
              await db.query(
                `INSERT INTO enterprise_bills (
                  store_id, bill_number, table_number, items,
                  subtotal, gst_percent, gst_amount, total_amount, payment_mode, created_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, COALESCE($10, NOW()))
                ON CONFLICT (store_id, bill_number) DO NOTHING`,
                [
                  store.id,
                  finalBillNumber,
                  p.table_number || p.tableNumber || 'Table 1',
                  JSON.stringify(p.items || []),
                  Number(p.subtotal || 0),
                  Number(p.gst_percent ?? p.gstPercent ?? 0),
                  Number(p.gst_amount ?? p.gstAmount ?? 0),
                  Number(p.total_amount ?? p.totalAmount ?? 0),
                  p.payment_mode || p.paymentMode || 'Cash',
                  p.created_at || p.createdAt || null,
                ]
              );
              break;
            }

            case 'save_profile': {
              await db.query(
                `UPDATE enterprise_stores SET
                  owner_name = COALESCE($1, owner_name),
                  restaurant_name = COALESCE($2, restaurant_name),
                  mobile_number = COALESCE($3, mobile_number),
                  city = COALESCE($4, city),
                  state = COALESCE($5, state),
                  upi_id = COALESCE($6, upi_id),
                  gst_percent = COALESCE($7, gst_percent),
                  tables_count = COALESCE($8, tables_count),
                  bill_prefix = COALESCE($9, bill_prefix),
                  theme = COALESCE($10, theme),
                  notifications_enabled = COALESCE($11, notifications_enabled),
                  enabled_modules = COALESCE($12, enabled_modules),
                  updated_at = NOW()
                 WHERE id = $13`,
                [
                  p.owner_name,
                  p.restaurant_name,
                  p.mobile_number,
                  p.city,
                  p.state,
                  p.upi_id,
                  p.gst_percent != null ? Number(p.gst_percent) : null,
                  p.tables_count != null ? Number(p.tables_count) : null,
                  p.bill_prefix,
                  p.theme,
                  p.notifications_enabled,
                  p.enabled_modules ? JSON.stringify(p.enabled_modules) : null,
                  store.id,
                ]
              );
              break;
            }

            case 'add_food_item': {
              if (p.name) {
                await db.query(
                  `INSERT INTO enterprise_food_items (store_id, name, category, price)
                   VALUES ($1, $2, $3, $4)`,
                  [store.id, String(p.name).trim(), (p.category || 'Main').trim(), Number(p.price || 0)]
                );
              }
              break;
            }

            case 'bulk_import_food_items': {
              if (Array.isArray(p.items)) {
                for (const item of p.items) {
                  if (!item || !item.name) continue;
                  await db.query(
                    `INSERT INTO enterprise_food_items (store_id, name, category, price)
                     VALUES ($1, $2, $3, $4)`,
                    [store.id, String(item.name).trim(), (item.category || 'Main').trim(), Number(item.price || 0)]
                  );
                }
              }
              break;
            }

            case 'update_food_item': {
              if (p.id || p.name) {
                await db.query(
                  `UPDATE enterprise_food_items
                   SET name = COALESCE($1, name),
                       category = COALESCE($2, category),
                       price = COALESCE($3, price),
                       updated_at = NOW()
                   WHERE (id::text = $4 OR name = $1) AND store_id = $5`,
                  [
                    p.name ? String(p.name).trim() : null,
                    p.category ? String(p.category).trim() : null,
                    p.price != null ? Number(p.price) : null,
                    String(p.id || ''),
                    store.id,
                  ]
                );
              }
              break;
            }

            case 'delete_food_item': {
              const target = String(p.id || p.name || '');
              if (target) {
                await db.query(
                  'DELETE FROM enterprise_food_items WHERE (id::text = $1 OR name = $1) AND store_id = $2',
                  [target, store.id]
                );
              }
              break;
            }

            case 'add_inventory': {
              const itemName = (p.item_name || p.itemName || '').trim();
              if (itemName) {
                await db.query(
                  `INSERT INTO enterprise_inventory (store_id, item_name, quantity, amount, vendor, purchase_date)
                   VALUES ($1, $2, $3, $4, $5, $6)`,
                  [
                    store.id,
                    itemName,
                    Number(p.quantity || 1),
                    Number(p.amount || 0),
                    p.vendor || '',
                    p.purchase_date || p.purchaseDate || new Date().toISOString().split('T')[0],
                  ]
                );
              }
              break;
            }

            case 'bulk_import_inventory': {
              if (Array.isArray(p.items)) {
                for (const item of p.items) {
                  if (!item) continue;
                  const name = (item.item_name || item.itemName || '').trim();
                  if (!name) continue;
                  await db.query(
                    `INSERT INTO enterprise_inventory (store_id, item_name, quantity, amount, vendor, purchase_date)
                     VALUES ($1, $2, $3, $4, $5, $6)`,
                    [
                      store.id,
                      name,
                      Number(item.quantity || 1),
                      Number(item.amount || 0),
                      item.vendor || '',
                      item.purchase_date || item.purchaseDate || new Date().toISOString().split('T')[0],
                    ]
                  );
                }
              }
              break;
            }

            case 'update_inventory': {
              if (p.id) {
                await db.query(
                  `UPDATE enterprise_inventory
                   SET item_name = COALESCE($1, item_name),
                       quantity = COALESCE($2, quantity),
                       amount = COALESCE($3, amount),
                       vendor = COALESCE($4, vendor)
                   WHERE id::text = $5 AND store_id = $6`,
                  [
                    p.item_name || p.itemName ? String(p.item_name || p.itemName).trim() : null,
                    p.quantity != null ? Number(p.quantity) : null,
                    p.amount != null ? Number(p.amount) : null,
                    p.vendor,
                    String(p.id),
                    store.id,
                  ]
                );
              }
              break;
            }

            case 'delete_inventory': {
              if (p.id) {
                await db.query('DELETE FROM enterprise_inventory WHERE id::text = $1 AND store_id = $2', [String(p.id), store.id]);
              }
              break;
            }

            case 'add_udhaar': {
              const cust = (p.customer_name || p.customerName || '').trim();
              if (cust && p.type) {
                await db.query(
                  `INSERT INTO enterprise_udhaar (store_id, customer_name, amount, type, transaction_date, notes)
                   VALUES ($1, $2, $3, $4, $5, $6)`,
                  [
                    store.id,
                    cust,
                    Number(p.amount || 0),
                    p.type,
                    p.transaction_date || p.transactionDate || new Date().toISOString().split('T')[0],
                    p.notes || '',
                  ]
                );
              }
              break;
            }

            case 'update_udhaar': {
              if (p.id) {
                await db.query(
                  `UPDATE enterprise_udhaar
                   SET customer_name = COALESCE($1, customer_name),
                       amount = COALESCE($2, amount),
                       type = COALESCE($3, type),
                       notes = COALESCE($4, notes)
                   WHERE id::text = $5 AND store_id = $6`,
                  [
                    p.customer_name || p.customerName ? String(p.customer_name || p.customerName).trim() : null,
                    p.amount != null ? Number(p.amount) : null,
                    p.type,
                    p.notes,
                    String(p.id),
                    store.id,
                  ]
                );
              }
              break;
            }

            case 'delete_udhaar': {
              if (p.id) {
                await db.query('DELETE FROM enterprise_udhaar WHERE id::text = $1 AND store_id = $2', [String(p.id), store.id]);
              }
              break;
            }

            case 'add_staff': {
              const name = (p.name || '').trim();
              const post = (p.post || '').trim();
              if (name && post) {
                await db.query(
                  `INSERT INTO enterprise_staff (store_id, name, post, salary, joining_date)
                   VALUES ($1, $2, $3, $4, $5)`,
                  [
                    store.id,
                    name,
                    post,
                    Number(p.salary || 0),
                    p.joining_date || p.joiningDate || new Date().toISOString().split('T')[0],
                  ]
                );
              }
              break;
            }

            case 'update_staff': {
              if (p.id) {
                await db.query(
                  `UPDATE enterprise_staff
                   SET name = COALESCE($1, name),
                       post = COALESCE($2, post),
                       salary = COALESCE($3, salary)
                   WHERE id::text = $4 AND store_id = $5`,
                  [
                    p.name ? String(p.name).trim() : null,
                    p.post ? String(p.post).trim() : null,
                    p.salary != null ? Number(p.salary) : null,
                    String(p.id),
                    store.id,
                  ]
                );
              }
              break;
            }

            case 'delete_staff': {
              if (p.id) {
                await db.query('DELETE FROM enterprise_staff WHERE id::text = $1 AND store_id = $2', [String(p.id), store.id]);
              }
              break;
            }

            case 'add_staff_advance': {
              const staffId = p.staff_id || p.staffId;
              if (staffId && p.amount != null) {
                const { rows: matchedStaff } = await db.query(
                  'SELECT id FROM enterprise_staff WHERE (id::text = $1 OR name = $1) AND store_id = $2 LIMIT 1',
                  [String(staffId), store.id]
                );
                if (matchedStaff.length > 0) {
                  await db.query(
                    `INSERT INTO enterprise_staff_advances (staff_id, store_id, amount, advance_date, notes)
                     VALUES ($1, $2, $3, $4, $5)`,
                    [
                      matchedStaff[0].id,
                      store.id,
                      Number(p.amount),
                      p.advance_date || p.advanceDate || new Date().toISOString().split('T')[0],
                      p.notes || '',
                    ]
                  );
                }
              }
              break;
            }

            default:
              break;
          }
        } catch (mutErr) {
          console.warn(`[SyncDelta] Mutation '${m.type}' warning:`, mutErr.message);
        }
      }
    }

    const updatedStore = await getOrCreateStore(req.user.uid, req.user.email);
    const consolidated = await buildConsolidatedResponse(updatedStore);
    return res.json(consolidated);
  } catch (error) {
    console.error('syncDelta error:', error);
    return res.status(500).json({ error: 'Failed to synchronize delta' });
  }
};
