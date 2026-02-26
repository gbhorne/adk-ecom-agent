"""
NL2SQL E-Commerce Analytics Agent
Built with Google ADK + Custom BigQuery Tool + AgentTool

Demonstrates:
- Custom function tools (execute_sql, get_schema, list_tables)
- AgentTool pattern (sql_validator agent used as a tool by the root agent)
- before_tool_callback / after_tool_callback for logging
- Safety guardrails (blocked keywords, read-only enforcement)
"""

import subprocess
from google.oauth2.credentials import Credentials
from google.cloud import bigquery
from google.adk.agents import Agent
from google.adk.tools.agent_tool import AgentTool

# -------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------
PROJECT_ID = "playground-s-11-6d7b503d"
DATASET_ID = "ecom_analytics"
MODEL_ID = "gemini-2.5-flash"

# Get credentials from gcloud CLI (bypasses broken metadata server in sandbox)
token = subprocess.check_output(
    ["gcloud", "auth", "print-access-token"]
).decode().strip()
credentials = Credentials(token=token)
bq_client = bigquery.Client(project=PROJECT_ID, credentials=credentials)

# -------------------------------------------------------------------------
# Blocked SQL keywords (safety guardrail)
# -------------------------------------------------------------------------
BLOCKED_KEYWORDS = [
    "DELETE", "DROP", "TRUNCATE", "UPDATE", "INSERT",
    "ALTER", "CREATE", "MERGE", "GRANT", "REVOKE",
]


# -------------------------------------------------------------------------
# Custom BigQuery Tools
# -------------------------------------------------------------------------
def execute_sql(query: str) -> dict:
    """Execute a read-only SQL query against BigQuery and return results.

    Args:
        query: A BigQuery SQL query string. Must be a SELECT statement.
            Always use fully qualified table names like:
            playground-s-11-6d7b503d.ecom_analytics.table_name

    Returns:
        A dictionary with status and either results or error message.
    """
    sql_upper = query.upper().strip()
    for keyword in BLOCKED_KEYWORDS:
        if keyword in sql_upper.split():
            return {
                "status": "blocked",
                "message": (
                    f"Query blocked: contains '{keyword}' operation. "
                    f"This agent is read-only and cannot modify data."
                ),
            }

    try:
        query_job = bq_client.query(query)
        results = query_job.result()

        rows = []
        for row in results:
            rows.append(dict(row))

        return {
            "status": "success",
            "row_count": len(rows),
            "results": rows[:50],
        }
    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
        }


def get_schema(table_name: str) -> dict:
    """Get the schema for a BigQuery table.

    Args:
        table_name: Just the table name (e.g., 'orders', 'customers', 'products').

    Returns:
        A dictionary with the table schema details.
    """
    try:
        table_ref = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"
        table = bq_client.get_table(table_ref)

        columns = []
        for field in table.schema:
            columns.append({
                "name": field.name,
                "type": field.field_type,
                "mode": field.mode,
            })

        return {
            "status": "success",
            "table": table_ref,
            "total_rows": table.num_rows,
            "columns": columns,
        }
    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
        }


def list_tables() -> dict:
    """List all available tables in the ecom_analytics dataset.

    Returns:
        A dictionary with the list of table names.
    """
    try:
        tables = bq_client.list_tables(f"{PROJECT_ID}.{DATASET_ID}")
        table_list = [t.table_id for t in tables]
        return {
            "status": "success",
            "dataset": f"{PROJECT_ID}.{DATASET_ID}",
            "tables": table_list,
        }
    except Exception as e:
        return {
            "status": "error",
            "message": str(e),
        }


# -------------------------------------------------------------------------
# Callbacks
# -------------------------------------------------------------------------
def before_tool_callback(tool, args, tool_context):
    """Log every tool call before execution."""
    print(f"BEFORE TOOL | {tool.name} | Args: {str(args)[:200]}")
    return None


def after_tool_callback(tool, args, tool_context, tool_response):
    """Audit log every tool call and result."""
    response_preview = str(tool_response)[:300]
    print(f"AUDIT LOG | Tool: {tool.name} | Response: {response_preview}")
    return None


# -------------------------------------------------------------------------
# SQL Validator Agent (used as AgentTool by the root agent)
# -------------------------------------------------------------------------
sql_validator_agent = Agent(
    name="sql_validator",
    model=MODEL_ID,
    description="Reviews SQL queries for correctness and safety before execution",
    instruction="""You are a SQL review specialist. When given a SQL query, you review it and respond with a brief assessment.

CHECK FOR:
1. SAFETY: Does it contain any write operations (DELETE, UPDATE, INSERT, DROP, ALTER, CREATE, TRUNCATE, MERGE, GRANT, REVOKE)? If yes, mark as UNSAFE.
2. SYNTAX: Is it valid BigQuery Standard SQL?
3. TABLE REFERENCES: Does it use fully qualified table names (project.dataset.table)?
4. PERFORMANCE: Any obvious issues like SELECT * on large tables without LIMIT?

RESPOND IN THIS FORMAT:
- VERDICT: SAFE or UNSAFE
- ISSUES: List any problems found, or "None" if clean
- SUGGESTION: Any improvements, or "None" if the query looks good

Keep your response concise. Do not execute anything. Just review.
""",
)

sql_validator_tool = AgentTool(agent=sql_validator_agent)

# -------------------------------------------------------------------------
# Root Agent Instructions
# -------------------------------------------------------------------------
AGENT_INSTRUCTIONS = """You are a helpful data analyst for an online electronics retailer.
You answer questions about orders, customers, and products by querying the
ecom_analytics dataset in BigQuery.

WORKFLOW:
1. If you need to understand the data, use list_tables() and get_schema() first
2. Write your SQL query
3. For complex queries (joins, aggregations, subqueries), use the sql_validator
   tool first to review the query before executing it
4. Execute the query with execute_sql()
5. Present the results in a clear, conversational way

For simple queries like COUNT(*) or basic SELECTs, you can skip validation
and go straight to execute_sql().

IMPORTANT: Always use fully qualified table names in SQL:
- playground-s-11-6d7b503d.ecom_analytics.products
- playground-s-11-6d7b503d.ecom_analytics.customers
- playground-s-11-6d7b503d.ecom_analytics.orders

TABLE DETAILS:

1. products (50 rows): product_id, product_name, category, subcategory, brand,
   unit_price, unit_cost, avg_rating, total_reviews, is_active

2. customers (30 rows): customer_id, first_name, last_name, email, region, state,
   city, loyalty_tier, signup_date, total_orders, lifetime_value

3. orders (100 rows): order_id, customer_id, order_date, order_status, payment_method,
   subtotal, discount_amount, shipping_cost, tax_amount, total_amount,
   items_count, shipping_region

KEY RELATIONSHIPS:
- orders.customer_id joins to customers.customer_id

GUIDELINES:
1. Always use fully qualified table paths as shown above
2. Use clear column aliases in your SQL
3. Round monetary values to 2 decimal places
4. When asked about revenue, use total_amount from the orders table
5. When asked about profit margins, calculate: (unit_price - unit_cost) / unit_price
6. For time-based questions, use the order_date field
7. Present results clearly with context, not just raw numbers
8. If a question is ambiguous, ask for clarification
9. You are READ-ONLY. Never attempt to modify data.
10. If you are unsure about the data, say so honestly.
"""

# -------------------------------------------------------------------------
# Root Agent Definition
# -------------------------------------------------------------------------
root_agent = Agent(
    name="ecom_analyst",
    model=MODEL_ID,
    description="Answers questions about e-commerce data using BigQuery",
    instruction=AGENT_INSTRUCTIONS,
    tools=[execute_sql, get_schema, list_tables, sql_validator_tool],
    before_tool_callback=before_tool_callback,
    after_tool_callback=after_tool_callback,
)
