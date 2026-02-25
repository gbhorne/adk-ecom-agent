# NL2SQL E-Commerce Analytics Agent

A conversational data analyst built with Google Agent Development Kit (ADK) that answers natural language questions about an online electronics retailer by generating and executing SQL against BigQuery.

## What It Does

Ask questions in plain English. The agent writes SQL, runs it against BigQuery, and returns clear answers.

**Examples:**
- "How many orders do we have in total?" -> Queries BigQuery, returns "100 orders"
- "Who are our top 3 customers by spending?" -> Joins customers + orders tables, returns ranked list
- "Delete all records from the orders table" -> Blocked. Agent refuses and explains it is read-only.

## Architecture
```
User Question
    |
    v
[Root Agent: ecom_analyst] -- Gemini 2.5 Flash
    |
    |-- execute_sql()      Custom tool: runs read-only SQL against BigQuery
    |-- get_schema()       Custom tool: returns table column details
    |-- list_tables()      Custom tool: lists available tables
    |-- [sql_validator]    AgentTool: reviews complex SQL before execution
    |
    v
BigQuery (ecom_analytics dataset)
    |-- products (50 rows)
    |-- customers (30 rows)
    |-- orders (100 rows)
```

## ADK Patterns Demonstrated

| Pattern | Implementation |
|---------|---------------|
| Custom Function Tools | execute_sql, get_schema, list_tables |
| AgentTool | sql_validator agent used as a tool by root agent |
| before_tool_callback | Logs every tool call before execution |
| after_tool_callback | Audit trail of all tool calls and responses |
| Safety Guardrails | Blocked SQL keywords + read-only instructions |
| Eval Set | 10 test cases with rubrics in ADK eval format |

## Project Structure
```
adk-ecom-agent/
  ecom_agent/
    __init__.py              # Package init, imports agent module
    agent.py                 # Agent definition, tools, callbacks
    .env                     # API key config (not committed)
    ecom_eval.evalset.json   # 10 evaluation test cases
  README.md
  ARCHITECTURE.md
  BUILD_GUIDE.md
```

## Prerequisites

- GCP project with BigQuery API enabled
- Python 3.10+
- Google ADK (`pip install google-adk`)
- Gemini API key from AI Studio (https://aistudio.google.com/apikey)

## Quick Start
```bash
# 1. Clone and set up
cd adk-ecom-agent
python3 -m venv .venv
source .venv/bin/activate
pip install google-adk google-cloud-bigquery

# 2. Set your API key
export GOOGLE_API_KEY="your-key-here"

# 3. Update .env
echo "GOOGLE_GENAI_USE_VERTEXAI=FALSE" > ecom_agent/.env
echo "GOOGLE_API_KEY=${GOOGLE_API_KEY}" >> ecom_agent/.env

# 4. Launch
adk web .
```

Open the Web Preview on port 8000. Select `ecom_agent` from the dropdown. Start asking questions.

## Dataset

The `ecom_analytics` dataset contains three tables modeled on an online electronics retailer:

| Table | Rows | Key Columns |
|-------|------|-------------|
| products | 50 | product_id, product_name, category, brand, unit_price, unit_cost |
| customers | 30 | customer_id, first_name, last_name, region, loyalty_tier, lifetime_value |
| orders | 100 | order_id, customer_id, order_date, total_amount, payment_method |

## Safety

The agent enforces read-only access through three layers:

1. **Instruction-level**: The agent is told it is read-only and should never modify data
2. **Tool-level**: The execute_sql function checks for blocked keywords (DELETE, DROP, UPDATE, INSERT, ALTER, CREATE, TRUNCATE, MERGE, GRANT, REVOKE) before running any query
3. **AgentTool-level**: The sql_validator can review queries for safety before execution

## Evaluation

10 test cases are included in `ecom_agent/ecom_eval.evalset.json` covering:
- Basic queries (order count, product listing)
- Aggregations (revenue by region, payment methods)
- Cross-table joins (top customers, tier comparisons)
- Time-based analysis (monthly revenue)
- Calculated fields (profit margins)
- Safety (DELETE blocked)
- Schema discovery (get_schema tool usage)

Run evals from the ADK Web UI Eval tab, or via CLI:
```bash
adk eval ecom_agent ecom_agent/ecom_eval.evalset.json
```
