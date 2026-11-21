-- =====================================================================
-- 06_docs_and_search.sql | Unstructured knowledge + Cortex Search service
-- All content below is SYNTHETIC (written for this demo project).
-- =====================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE AI_LAB_WH;
USE SCHEMA AI_LAB.DOCS;

CREATE OR REPLACE TABLE POLICY_NOTES (
  DOC_ID   NUMBER,
  TITLE    STRING,
  CATEGORY STRING,
  CONTENT  STRING
);

INSERT INTO POLICY_NOTES VALUES
 (1, 'Order status codes', 'Definitions',
  'Orders carry a one-letter status. F means fulfilled: every line item has shipped. O means open: the order is still outstanding. P means partially fulfilled: some line items have shipped and others are pending.'),
 (2, 'Late delivery definition and SLA', 'Policy',
  'A line item is late when its receipt date is after its commit date. If more than 10 percent of line items on an order are late, the order goes to the logistics team for a root-cause review within five business days.'),
 (3, 'Discount approval policy', 'Policy',
  'Line-item discounts up to 5 percent can be given by account managers. Discounts above 5 percent and up to 10 percent need regional manager approval. Anything above 10 percent needs finance approval.'),
 (4, 'Returns handling', 'Policy',
  'Return flag R means the customer returned the item. A means the return was accepted after inspection and credited. N means the item was not returned. Returned items are excluded from the customer satisfaction score.'),
 (5, 'Inventory reorder policy', 'Policy',
  'Reorder a part from a supplier when available quantity falls below 500 units. Parts with available quantity below 100 units are flagged critical and escalated to procurement the same day.'),
 (6, 'Customer segments', 'Definitions',
  'Customers are grouped into five market segments: AUTOMOBILE, BUILDING, FURNITURE, HOUSEHOLD and MACHINERY. Segment is assigned at onboarding and reviewed once a year.'),
 (7, 'Order priority levels', 'Definitions',
  'Priority 1-URGENT orders must ship within 24 hours. 2-HIGH ships within 48 hours. 3-MEDIUM within five days. 4-NOT SPECIFIED and 5-LOW follow standard scheduling.'),
 (8, 'Regional data access rules', 'Governance',
  'Regional analysts can only see customers, orders and suppliers in their own region. Phone numbers are masked for everyone except the global analytics role. Share aggregated figures, not personal data, outside the team.');

ALTER TABLE POLICY_NOTES SET CHANGE_TRACKING = TRUE;

CREATE OR REPLACE CORTEX SEARCH SERVICE AI_LAB.SEMANTIC.POLICY_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY
  WAREHOUSE = AI_LAB_WH
  TARGET_LAG = '1 day'
AS (
  SELECT DOC_ID, TITLE, CATEGORY, CONTENT FROM AI_LAB.DOCS.POLICY_NOTES
);

GRANT USAGE ON CORTEX SEARCH SERVICE AI_LAB.SEMANTIC.POLICY_SEARCH TO ROLE AI_ROLE_GLOBAL;
GRANT USAGE ON CORTEX SEARCH SERVICE AI_LAB.SEMANTIC.POLICY_SEARCH TO ROLE AI_ROLE_ASIA;
GRANT USAGE ON CORTEX SEARCH SERVICE AI_LAB.SEMANTIC.POLICY_SEARCH TO ROLE AI_ROLE_EUROPE;

-- Smoke test (wait a minute after creation for the index to build)
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'AI_LAB.SEMANTIC.POLICY_SEARCH',
    '{"query": "when is a delivery considered late", "columns": ["TITLE","CONTENT"], "limit": 2}'
  )
)['results'] AS results;