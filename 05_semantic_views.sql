-- =====================================================================
-- 05_semantic_views.sql | The "meaning layer" Cortex Analyst reads
-- V1 = minimal (no comments/synonyms)  -> measure accuracy
-- V2 = refined (comments, synonyms, code meanings) -> measure again
-- The accuracy gap between V1 and V2 is your headline result.
-- =====================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE AI_LAB_WH;
USE SCHEMA AI_LAB.SEMANTIC;

-- ---------------------------------------------------------------------
-- V1: baseline
-- ---------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW AI_LAB.SEMANTIC.SALES_SV_V1
  TABLES (
    orders    AS AI_LAB.GOLD.FCT_ORDERS      PRIMARY KEY (ORDER_KEY),
    lines     AS AI_LAB.GOLD.FCT_ORDER_LINES PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    customers AS AI_LAB.GOLD.DIM_CUSTOMER    PRIMARY KEY (CUSTOMER_KEY),
    parts     AS AI_LAB.GOLD.DIM_PART        PRIMARY KEY (PART_KEY),
    suppliers AS AI_LAB.GOLD.DIM_SUPPLIER    PRIMARY KEY (SUPPLIER_KEY),
    inventory AS AI_LAB.GOLD.FCT_INVENTORY   PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
  )
  RELATIONSHIPS (
    orders_to_customers  AS orders    (CUSTOMER_KEY) REFERENCES customers,
    lines_to_orders      AS lines     (ORDER_KEY)    REFERENCES orders,
    lines_to_parts       AS lines     (PART_KEY)     REFERENCES parts,
    lines_to_suppliers   AS lines     (SUPPLIER_KEY) REFERENCES suppliers,
    inventory_to_parts   AS inventory (PART_KEY)     REFERENCES parts,
    inventory_to_suppliers AS inventory (SUPPLIER_KEY) REFERENCES suppliers
  )
  DIMENSIONS (
    customers.customer_name   AS customers.CUSTOMER_NAME,
    customers.market_segment  AS customers.MARKET_SEGMENT,
    customers.customer_nation AS customers.NATION_NAME,
    customers.customer_region AS customers.REGION_NAME,
    customers.customer_phone  AS customers.PHONE,
    parts.part_name           AS parts.PART_NAME,
    parts.brand               AS parts.BRAND,
    parts.manufacturer        AS parts.MANUFACTURER,
    parts.part_type           AS parts.PART_TYPE,
    suppliers.supplier_name   AS suppliers.SUPPLIER_NAME,
    suppliers.supplier_nation AS suppliers.NATION_NAME,
    suppliers.supplier_region AS suppliers.REGION_NAME,
    orders.order_date         AS orders.ORDER_DATE,
    orders.order_year         AS orders.ORDER_YEAR,
    orders.order_month        AS DATE_TRUNC('month', orders.ORDER_DATE),
    orders.order_status       AS orders.ORDER_STATUS,
    orders.order_priority     AS orders.ORDER_PRIORITY,
    lines.ship_mode           AS lines.SHIP_MODE,
    lines.return_flag         AS lines.RETURN_FLAG,
    lines.is_late_delivery    AS lines.IS_LATE_DELIVERY
  )
  METRICS (
    orders.order_count            AS COUNT(orders.ORDER_KEY),
    orders.avg_order_value        AS AVG(orders.TOTAL_PRICE),
    orders.max_order_value        AS MAX(orders.TOTAL_PRICE),
    lines.net_revenue             AS SUM(lines.NET_AMOUNT),
    lines.total_quantity          AS SUM(lines.QUANTITY),
    lines.avg_line_quantity       AS AVG(lines.QUANTITY),
    lines.line_count              AS COUNT(lines.LINE_NUMBER),
    customers.customer_count      AS COUNT(customers.CUSTOMER_KEY),
    customers.avg_account_balance AS AVG(customers.ACCOUNT_BALANCE),
    parts.part_count              AS COUNT(parts.PART_KEY),
    suppliers.supplier_count      AS COUNT(suppliers.SUPPLIER_KEY),
    inventory.total_available_qty AS SUM(inventory.AVAILABLE_QTY),
    inventory.total_inventory_value AS SUM(inventory.INVENTORY_VALUE)
  );

-- ---------------------------------------------------------------------
-- V2: refined with business language
-- ---------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW AI_LAB.SEMANTIC.SALES_SV_V2
  TABLES (
    orders    AS AI_LAB.GOLD.FCT_ORDERS      PRIMARY KEY (ORDER_KEY)
      WITH SYNONYMS = ('sales orders', 'purchase orders')
      COMMENT = 'One row per customer order. Use for order counts and order value.',
    lines     AS AI_LAB.GOLD.FCT_ORDER_LINES PRIMARY KEY (ORDER_KEY, LINE_NUMBER)
      WITH SYNONYMS = ('line items', 'order lines', 'shipments')
      COMMENT = 'One row per order line. Use for revenue, quantity and delivery analysis.',
    customers AS AI_LAB.GOLD.DIM_CUSTOMER    PRIMARY KEY (CUSTOMER_KEY)
      WITH SYNONYMS = ('clients', 'buyers')
      COMMENT = 'Customer master data with nation and region.',
    parts     AS AI_LAB.GOLD.DIM_PART        PRIMARY KEY (PART_KEY)
      WITH SYNONYMS = ('products', 'items', 'materials')
      COMMENT = 'Part / product master data.',
    suppliers AS AI_LAB.GOLD.DIM_SUPPLIER    PRIMARY KEY (SUPPLIER_KEY)
      WITH SYNONYMS = ('vendors')
      COMMENT = 'Supplier master data with nation and region.',
    inventory AS AI_LAB.GOLD.FCT_INVENTORY   PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
      WITH SYNONYMS = ('stock', 'stock levels', 'supply')
      COMMENT = 'Available quantity and supply cost per part and supplier.'
  )
  RELATIONSHIPS (
    orders_to_customers  AS orders    (CUSTOMER_KEY) REFERENCES customers,
    lines_to_orders      AS lines     (ORDER_KEY)    REFERENCES orders,
    lines_to_parts       AS lines     (PART_KEY)     REFERENCES parts,
    lines_to_suppliers   AS lines     (SUPPLIER_KEY) REFERENCES suppliers,
    inventory_to_parts   AS inventory (PART_KEY)     REFERENCES parts,
    inventory_to_suppliers AS inventory (SUPPLIER_KEY) REFERENCES suppliers
  )
  DIMENSIONS (
    customers.customer_name   AS customers.CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'client name') COMMENT = 'Customer name, e.g. Customer#000000001.',
    customers.market_segment  AS customers.MARKET_SEGMENT
      WITH SYNONYMS = ('segment', 'industry', 'customer segment')
      COMMENT = 'Customer segment. Values: AUTOMOBILE, BUILDING, FURNITURE, HOUSEHOLD, MACHINERY (uppercase).',
    customers.customer_nation AS customers.NATION_NAME
      WITH SYNONYMS = ('customer country', 'country') COMMENT = 'Nation of the customer, in Title Case.',
    customers.customer_region AS customers.REGION_NAME
      WITH SYNONYMS = ('region', 'sales region', 'customer geography')
      COMMENT = 'Region of the customer. Values: Africa, America, Asia, Europe, Middle East.',
    customers.customer_phone  AS customers.PHONE
      WITH SYNONYMS = ('phone', 'phone number', 'contact number', 'telephone')
      COMMENT = 'Customer phone number. Masked (XXX-XXX-last4) for every role except the global analytics role.',
    parts.part_name           AS parts.PART_NAME  COMMENT = 'Descriptive part name.',
    parts.brand               AS parts.BRAND
      WITH SYNONYMS = ('product brand') COMMENT = 'Part brand, format Brand#NN, e.g. Brand#23.',
    parts.manufacturer        AS parts.MANUFACTURER
      WITH SYNONYMS = ('maker', 'mfgr') COMMENT = 'Manufacturer, format Manufacturer#N.',
    parts.part_type           AS parts.PART_TYPE
      WITH SYNONYMS = ('type', 'material type')
      COMMENT = 'Part type text, e.g. STANDARD POLISHED BRASS. Use LIKE for material words such as BRASS, COPPER, STEEL, TIN, NICKEL.',
    suppliers.supplier_name   AS suppliers.SUPPLIER_NAME   WITH SYNONYMS = ('vendor name'),
    suppliers.supplier_nation AS suppliers.NATION_NAME     WITH SYNONYMS = ('supplier country'),
    suppliers.supplier_region AS suppliers.REGION_NAME
      WITH SYNONYMS = ('supplier geography', 'vendor region')
      COMMENT = 'Region of the supplier. Values: Africa, America, Asia, Europe, Middle East.',
    orders.order_date         AS orders.ORDER_DATE        COMMENT = 'Date the order was placed (1992-1998).',
    orders.order_year         AS orders.ORDER_YEAR        WITH SYNONYMS = ('year', 'calendar year'),
    orders.order_month        AS DATE_TRUNC('month', orders.ORDER_DATE) WITH SYNONYMS = ('month'),
    orders.order_status       AS orders.ORDER_STATUS
      WITH SYNONYMS = ('status', 'fulfilment status')
      COMMENT = 'Order status code. F = fulfilled (completed), O = open (still outstanding), P = partially fulfilled.',
    orders.order_priority     AS orders.ORDER_PRIORITY
      WITH SYNONYMS = ('priority', 'urgency')
      COMMENT = 'Values: 1-URGENT, 2-HIGH, 3-MEDIUM, 4-NOT SPECIFIED, 5-LOW. "Urgent" means 1-URGENT.',
    lines.ship_mode           AS lines.SHIP_MODE
      WITH SYNONYMS = ('shipping method', 'transport mode')
      COMMENT = 'Values: AIR, FOB, MAIL, RAIL, REG AIR, SHIP, TRUCK.',
    lines.return_flag         AS lines.RETURN_FLAG
      WITH SYNONYMS = ('returned', 'return status')
      COMMENT = 'R = returned by customer, A = accepted after inspection, N = not returned. "Returned items" means R.',
    lines.is_late_delivery    AS lines.IS_LATE_DELIVERY
      WITH SYNONYMS = ('late', 'delayed', 'late shipment')
      COMMENT = 'TRUE when the line item was received after its commit date.'
  )
  METRICS (
    orders.order_count            AS COUNT(orders.ORDER_KEY)
      WITH SYNONYMS = ('number of orders', 'total orders') COMMENT = 'Count of orders.',
    orders.avg_order_value        AS AVG(orders.TOTAL_PRICE)
      WITH SYNONYMS = ('average order size', 'AOV') COMMENT = 'Average order total price.',
    orders.max_order_value        AS MAX(orders.TOTAL_PRICE)
      WITH SYNONYMS = ('largest order', 'biggest order') COMMENT = 'Largest single order total price.',
    lines.net_revenue             AS SUM(lines.NET_AMOUNT)
      WITH SYNONYMS = ('revenue', 'sales', 'net sales', 'turnover')
      COMMENT = 'Revenue after discount: extended price x (1 - discount), summed over line items. Default measure for "revenue" or "sales".',
    lines.total_quantity          AS SUM(lines.QUANTITY)   WITH SYNONYMS = ('units sold', 'quantity sold'),
    lines.avg_line_quantity       AS AVG(lines.QUANTITY)   WITH SYNONYMS = ('average quantity per line'),
    lines.line_count              AS COUNT(lines.LINE_NUMBER) WITH SYNONYMS = ('number of line items'),
    customers.customer_count      AS COUNT(customers.CUSTOMER_KEY) WITH SYNONYMS = ('number of customers'),
    customers.avg_account_balance AS AVG(customers.ACCOUNT_BALANCE) WITH SYNONYMS = ('average balance'),
    parts.part_count              AS COUNT(parts.PART_KEY) WITH SYNONYMS = ('number of parts', 'number of products'),
    suppliers.supplier_count      AS COUNT(suppliers.SUPPLIER_KEY) WITH SYNONYMS = ('number of suppliers'),
    inventory.total_available_qty AS SUM(inventory.AVAILABLE_QTY)
      WITH SYNONYMS = ('stock quantity', 'units in stock', 'available inventory'),
    inventory.total_inventory_value AS SUM(inventory.INVENTORY_VALUE)
      WITH SYNONYMS = ('stock value', 'inventory worth') COMMENT = 'Available quantity x supply cost.'
  )
  COMMENT = 'Sales, inventory and delivery analytics on an ERP-style Gold star schema. Revenue always means net revenue.';

-- Grants (semantic views are queried by the analyst roles)
GRANT SELECT ON SEMANTIC VIEW AI_LAB.SEMANTIC.SALES_SV_V1 TO ROLE AI_ROLE_GLOBAL;
GRANT SELECT ON SEMANTIC VIEW AI_LAB.SEMANTIC.SALES_SV_V1 TO ROLE AI_ROLE_ASIA;
GRANT SELECT ON SEMANTIC VIEW AI_LAB.SEMANTIC.SALES_SV_V1 TO ROLE AI_ROLE_EUROPE;
GRANT SELECT ON SEMANTIC VIEW AI_LAB.SEMANTIC.SALES_SV_V2 TO ROLE AI_ROLE_GLOBAL;
GRANT SELECT ON SEMANTIC VIEW AI_LAB.SEMANTIC.SALES_SV_V2 TO ROLE AI_ROLE_ASIA;
GRANT SELECT ON SEMANTIC VIEW AI_LAB.SEMANTIC.SALES_SV_V2 TO ROLE AI_ROLE_EUROPE;

-- Smoke test (plain SQL against the semantic layer)
SELECT * FROM SEMANTIC_VIEW(
  AI_LAB.SEMANTIC.SALES_SV_V2
  DIMENSIONS customers.customer_region
  METRICS lines.net_revenue
) ORDER BY 1;