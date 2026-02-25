# Architecture: NL2SQL E-Commerce Analytics Agent

## System Overview

This agent translates natural language questions into BigQuery SQL, executes the queries, and presents results conversationally. It runs entirely within a GCP Cloud Shell sandbox using only BigQuery and Gemini via AI Studio (no Vertex AI, Cloud Run, or Cloud Functions required).

## Component Diagram
```
                    +------------------+
                    |    ADK Web UI    |
                    |   (port 8000)    |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    |   Root Agent     |
                    |  ecom_analyst    |
                    |  (Gemini 2.5     |
                    |   Flash)         |
                    +--------+---------+
                             |
              +--------------+--------------+
              |              |              |
              v              v              v
      +-------+----+  +-----+------+  +----+-------+
      | execute_sql |  | get_schema |  | list_tables|
      | (custom fn) |  | (custom fn)|  | (custom fn)|
      +-------+----+  +-----+------+  +----+-------+
              |              |              |
              v              v              v
        +------------------------------------+
        |         BigQuery Client            |
        |   (gcloud token credentials)       |
        +----------------+-------------------+
                         |
                         v
        +------------------------------------+
        |        BigQuery Dataset            |
        |       ecom_analytics               |
        |  +----------+  +-----------+       |
        |  | products |  | customers |       |
        |  +----------+  +-----------+       |
        |       +----------+                 |
        |       |  orders  |                 |
        |       +----------+                 |
        +------------------------------------+
```

## Agent Design

### Root Agent: ecom_analyst

The root agent receives user questions and decides which tools to call. It uses Gemini 2.5 Flash as the underlying LLM. The agent instructions provide table schemas, column details, and guidelines for SQL generation.

**Decision flow:**
1. Simple factual question about data -> execute_sql directly
2. Question about table structure -> get_schema
3. Question about available data -> list_tables
4. Complex query with joins/subqueries -> optionally sql_validator, then execute_sql
5. Destructive request (DELETE, DROP) -> refuse without calling any tool

### AgentTool: sql_validator

A second agent (also Gemini 2.5 Flash) that acts as a tool for the root agent. When called, it reviews a SQL query for safety, syntax, table references, and performance issues. It returns a verdict (SAFE/UNSAFE) with any issues found.

This demonstrates the ADK AgentTool pattern where one agent delegates specialized work to another agent.

## Tool Design

### execute_sql(query: str) -> dict

Runs a SQL query against BigQuery and returns results.

**Safety layers:**
1. Checks query against a blocklist of destructive keywords
2. Returns structured error if blocked
3. Caps results at 50 rows to prevent oversized responses

**Returns:** `{"status": "success|error|blocked", "row_count": int, "results": [...]}`

### get_schema(table_name: str) -> dict

Retrieves column names, types, and row count for a table.

**Returns:** `{"status": "success|error", "table": str, "total_rows": int, "columns": [...]}`

### list_tables() -> dict

Lists all tables in the ecom_analytics dataset.

**Returns:** `{"status": "success|error", "dataset": str, "tables": [...]}`

## Callback Architecture

### before_tool_callback

Called before every tool execution. Logs the tool name and arguments. Returns None to allow execution (blocking is handled inside the tools themselves).

### after_tool_callback

Called after every tool execution. Logs the tool name and a preview of the response for audit purposes.

## Credential Strategy

GCP sandbox environments have a known issue where the Compute Engine metadata server does not return the service account email field. This breaks both ADK's built-in BigQuery Toolset and the standard `google.auth.default()` flow.

**Solution:** We bypass the metadata server entirely by getting an access token from gcloud CLI and creating an `oauth2.credentials.Credentials` object directly. This works reliably in Cloud Shell.
```python
token = subprocess.check_output(["gcloud", "auth", "print-access-token"]).decode().strip()
credentials = Credentials(token=token)
bq_client = bigquery.Client(project=PROJECT_ID, credentials=credentials)
```

**Trade-off:** The token expires (typically after 1 hour). For a production deployment, you would use a service account with proper IAM roles instead.

## Data Model

The ecom_analytics dataset models an online electronics retailer with three tables designed for agent-friendly querying:

- **Descriptive column names** (total_amount, not amt_ttl) so the LLM can use them as semantic signals
- **Consistent data types** (STRING for IDs, FLOAT64 for money, DATE for dates)
- **Clear foreign keys** (orders.customer_id -> customers.customer_id)
- **Realistic distributions** across categories, regions, payment methods, and loyalty tiers

## Evaluation Strategy

10 eval cases test the agent across multiple dimensions:
- **Tool selection**: Does the agent pick the right tool?
- **SQL correctness**: Does the generated SQL answer the question?
- **Safety**: Does the agent refuse destructive operations?
- **Response quality**: Does the agent present results clearly?

Each case includes rubrics that can be assessed by an LLM judge or manually.
